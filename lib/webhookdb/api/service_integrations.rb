# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/aws"

class Webhookdb::API::ServiceIntegrations < Webhookdb::API::V1
  resource :service_integrations do
    route_param :opaque_id do
      helpers do
        def lookup_unauthed!
          sint = Webhookdb::ServiceIntegration[opaque_id: params[:opaque_id]]
          merror!(400, "No integration with that id") if sint.nil? || sint.soft_deleted?
          return sint
        end

        def log_webhook(sint, sstatus)
          # Status can be set from:
          # - the 'status' method, which will be 201 if it hasn't been set,
          # or another value if it has been set.
          # - the webhook responder, which could respond with 401, etc
          # - if there was an exception- so no status is set yet- use 0
          # The main thing to watch out for is that we:
          # - Cannot assume an exception is a 500 (it can be rescued later)
          # - Must handle error! calls
          # Anyway, this is all pretty confusing, but it's all tested.
          rstatus = status == 201 ? (sstatus || 0) : status
          request.body.rewind
          Webhookdb::LoggedWebhook.dataset.insert(
            request_body: request.body.read,
            request_headers: request.headers.to_json,
            response_status: rstatus,
            organization_id: sint&.organization_id,
            service_integration_opaque_id: params[:opaque_id],
          )
        end
      end

      # this particular url (`v1/service_integrations/#{opaque_id}`) is not used by the CLI-
      # it is the url that customers should point their webhooks to.
      # we can't check org permissions on this endpoint
      # because external services will be posting webhooks here
      # hence, it has a special lookup function
      post do
        sint = lookup_unauthed!
        svc = Webhookdb::Services.service_instance(sint)
        s_status, s_headers, s_body = svc.webhook_response(request)

        if s_status >= 400
          logger.warn "rejected_webhook", webhook_headers: request.headers.to_h,
                                          webhook_body: env["api.request.body"]
        else
          sint.publish_immediate("webhook", sint.id, {headers: request.headers, body: env["api.request.body"]})
        end

        env["api.format"] = :binary
        s_headers.each { |k, v| header k, v }
        body s_body
        status s_status
      ensure
        log_webhook(sint, s_status)
      end
    end
  end

  resource :organizations do
    route_param :org_identifier, type: String do
      resource :service_integrations do
        desc "Return all integrations associated with the organization."
        get do
          integrations = lookup_org!.service_integrations
          message = integrations.empty? ? "Organization doesn't have any integrations yet." : ""
          present_collection integrations, with: Webhookdb::API::ServiceIntegrationEntity, message:
        end

        resource :create do
          helpers do
            def create_integration(org, name)
              available_services_list = org.available_services.join("\n\t")

              # If provided service name is invalid
              if Webhookdb::Services.registered_service_type(name).nil?
                step = Webhookdb::Services::StateMachineStep.new
                step.needs_input = false
                step.output =
                  %(
WebhookDB doesn't support a service called '#{name}.' These are all the services
currently supported by WebhookDB:

\t#{available_services_list}

You can run `webhookdb services list` at any time to see our list of available services.
                    )
                step.complete = true
                return step
              end

              # If org does not have access to the given service
              unless org.available_services.include?(name)
                step = Webhookdb::Services::StateMachineStep.new
                step.needs_input = false
                step.output =
                  %(
Your organization does not have permission to view the service called '#{name}.' These are all the services
you currently have access to:

\t#{available_services_list}

You can run `webhookdb services list` at any time to see the list of services available to your organization.
If the list does not look correct, you can contact support at #{Webhookdb.support_email}.
                    )
                # maybe include a support email to contact? i'd want to add the support email as a config var
                step.complete = true
                return step
              end
              sint = Webhookdb::ServiceIntegration[organization: org, service_name: name]
              if sint.nil?
                sint = Webhookdb::ServiceIntegration.create(
                  organization: org,
                  table_name: (name + "_#{SecureRandom.hex(2)}"),
                  service_name: name,
                )
              end
              return sint.calculate_create_state_machine
            end
          end
          desc "Create service integration on a given organization"
          params do
            requires :service_name, type: String, allow_blank: false
          end
          post do
            customer = current_customer
            org = lookup_org!
            merror!(402, "You have reached the maximum number of free integrations") unless org.can_add_new_integration?
            ensure_admin!
            customer.db.transaction do
              state_machine = create_integration(org, params[:service_name])
              status 200
              present state_machine, with: Webhookdb::API::StateMachineEntity
            end
          end
        end

        route_param :opaque_id, type: String do
          helpers do
            def lookup!
              org = lookup_org!
              sint = Webhookdb::ServiceIntegration[opaque_id: params[:opaque_id], organization: org]
              merror!(400, "The current org has no integration with that id") if sint.nil? || sint.soft_deleted?
              return sint
            end

            def ensure_plan_supports!
              sint = lookup!
              # TODO: Fix this message?
              err_msg = "Integration no longer supported--please visit website to activate subscription."
              merror!(402, err_msg) unless sint.plan_supports_integration?
            end
          end

          resource :reset do
            post do
              ensure_plan_supports!
              c = current_customer
              sint = lookup!
              svc = Webhookdb::Services.service_instance(sint)
              merror!(403, "Sorry, you cannot modify this integration.") unless sint.can_be_modified_by?(c)
              svc.clear_create_information
              state_machine = svc.calculate_create_state_machine
              status 200
              present state_machine, with: Webhookdb::API::StateMachineEntity
            end
          end

          resource :backfill do
            post do
              ensure_plan_supports!
              c = current_customer
              sint = lookup!
              svc = Webhookdb::Services.service_instance(sint)
              merror!(403, "Sorry, you cannot modify this integration.") unless sint.can_be_modified_by?(c)
              state_machine = svc.calculate_backfill_state_machine
              if state_machine.complete
                Webhookdb.publish(
                  "webhookdb.serviceintegration.backfill", sint.id,
                )
              end
              status 200
              present state_machine, with: Webhookdb::API::StateMachineEntity
            end

            resource :reset do
              post do
                ensure_plan_supports!
                c = current_customer
                sint = lookup!
                svc = Webhookdb::Services.service_instance(sint)
                merror!(403, "Sorry, you cannot modify this integration.") unless sint.can_be_modified_by?(c)
                svc.clear_backfill_information
                state_machine = svc.calculate_backfill_state_machine
                status 200
                present state_machine, with: Webhookdb::API::StateMachineEntity
              end
            end
          end

          resource :transition do
            route_param :field do
              params do
                requires :value
              end
              post do
                ensure_plan_supports!
                c = current_customer
                sint = lookup!
                merror!(403, "Sorry, you cannot modify this integration.") unless sint.can_be_modified_by?(c)
                state_machine = sint.process_state_change(params[:field], params[:value])
                status 200
                present state_machine, with: Webhookdb::API::StateMachineEntity
              end
            end
          end
        end
      end
    end
  end
end
