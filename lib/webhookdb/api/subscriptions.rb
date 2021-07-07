# frozen_string_literal: true

require "grape"

require "webhookdb/api"
require "webhookdb/admin_api"

class Webhookdb::API::Subscriptions < Webhookdb::API::V1
  helpers do
    def lookup_org!
      customer = current_customer
      org = Webhookdb::Organization.lookup_by_identifier(params[:identifier])
      merror!(403, "There is no organization with that identifier.") if org.nil?
      membership = customer.memberships_dataset[organization: org, verified: true]
      merror!(403, "You don't have permissions with that organization.") if membership.nil?
      return membership.organization
    end

    def ensure_admin!
      customer = current_customer
      org = lookup_org!
      admin_membership = org.memberships_dataset[customer: customer, role: Webhookdb::OrganizationRole.admin_role]
      merror!(400, "Permission denied: You don't have admin privileges with #{org.name}.") if admin_membership.nil?
    end
  end

  resource :subscriptions do
    desc "Provides the user with subscription information for the organization"
    params do
      requires :identifier, type: String, allow_blank: false
    end
    get do
      org = lookup_org!
      status 200
      present Webhookdb::Subscription.status_for_org(org)
    end

    resource :open_portal do
      desc "Authenticates stripe user and returns stripe session url"
      params do
        requires :identifier, type: String, allow_blank: false
      end
      post do
        org = lookup_org!
        begin
          url = org.get_stripe_billing_portal_url
        rescue Webhookdb::InvalidPrecondition
          merror!(409, "This organization is not registered with Stripe.")
        end
        redirect(url, body: {url: url})
        content_type "application/json"
      end
    end

    resource :portal_return do
      desc "provides a landing page for after the stripe billing page"
      post do
        html_body = "<html>
<head>
    <title>Action Completed.</title>
</head>
<body>
<div>
  <p>You have successfully viewed or updated your Stripe Billing Information. You can close this page.</p>
</div>
</body>
</html>"
        redirect(Webhookdb.marketing_site, body: html_body)
        content_type "text/html"
      end
    end
  end
end