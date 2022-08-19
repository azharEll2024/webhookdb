# frozen_string_literal: true

require "webhookdb/spec_helpers"

# Set :whdbisolation metadatabase. Use the isolation mode, or :reset to just reset config
# before and after the spec.
module Webhookdb::SpecHelpers::Whdb
  def self.included(context)
    context.before(:each) do |example|
      if (isomode = example.metadata[:whdbisolation])
        Webhookdb::Organization::DbBuilder.isolation_mode = isomode if isomode.is_a?(String)
        Webhookdb::Organization::DbBuilder.reset_configuration if isomode == :reset
      end
      if (regress = example.metadata[:regression_mode])
        Webhookdb.regression_mode = regress
      end
    end

    context.after(:each) do |example|
      if (mode = example.metadata[:whdbisolation])
        Webhookdb::Organization.dataset.each(&:remove_related_database) if mode != :reset
        Webhookdb::Organization::DbBuilder.reset_configuration
      end
      Webhookdb.regression_mode = false if example.metadata[:regression_mode]
    end

    super
  end

  module_function def assign_connection_urls(o, **more)
    u = Webhookdb::Organization::DbBuilder.available_server_urls.sample
    raise "no server url?" if u.blank?
    o.update(
      readonly_connection_url_raw: u,
      admin_connection_url_raw: u,
      **more,
    )
  end

  module_function def create_dependency(service_integration)
    return service_integration.depends_on unless service_integration.depends_on.nil?
    dependency_descriptor = service_integration.service_instance.descriptor.dependency_descriptor
    if dependency_descriptor.present?
      dependency = Webhookdb::Fixtures.service_integration.create(
        organization: service_integration.organization,
        service_name: dependency_descriptor.name,
      )
      # For ease with the theranest tests, automatically populate theranest auth integrations
      # with username and password info.
      if dependency.service_name == "theranest_auth_v1"
        dependency.update(
          backfill_key: "username",
          backfill_secret: "password",
          api_url: "https://auth-api-url.com",
        )
      end
      service_integration.update(depends_on: dependency)
      return dependency
    end
    return nil
  end

  # If a service has dependencies, and those dependencies have dependencies, create
  # them recursively until all requirements are satisfied.
  module_function def create_all_dependencies(service_integration)
    sint = service_integration
    dependency_descriptor = sint.service_instance.descriptor.dependency_descriptor
    while dependency_descriptor.present?
      sint = create_dependency(sint)
      # now climb up the ladder
      dependency_descriptor = sint.present? ? sint.service_instance.descriptor.dependency_descriptor : nil
    end
  end
end
