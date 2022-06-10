# frozen_string_literal: true

require "time"
require "webhookdb/convertkit"
require "webhookdb/services/convertkit_v1_mixin"

class Webhookdb::Services::ConvertkitTagV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::ConvertkitV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "convertkit_tag_v1",
      ctor: ->(sint) { Webhookdb::Services::ConvertkitTagV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "ConvertKit Tag",
    )
  end

  def calculate_create_state_machine
    return self.calculate_backfill_state_machine
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:created_at, TIMESTAMP, index: true),
      Webhookdb::Services::Column.new(:name, TEXT, index: true),
      Webhookdb::Services::Column.new(:total_subscriptions, INTEGER),
    ]
  end

  def _timestamp_column_name
    return :created_at
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:data] !~ Sequel[:excluded][:data]
  end

  def upsert_has_deps?
    return true
  end

  def _fetch_enrichment(body)
    tag_id = body.fetch("id")
    url = "https://api.convertkit.com/v3/tags/#{tag_id}/subscriptions?api_secret=#{self.service_integration.backfill_secret}"
    Kernel.sleep(Webhookdb::Convertkit.sleep_seconds)
    response = Webhookdb::Http.get(url, logger: self.logger)
    data = response.parsed_response
    return data
  end

  def _prepare_for_insert(body, enrichment:)
    return {
      convertkit_id: body.fetch("id"),
      created_at: body.fetch("created_at"),
      name: body.fetch("name"),
      total_subscriptions: enrichment.fetch("total_subscriptions"),
    }
  end

  def _fetch_backfill_page(_pagination_token, **_kwargs)
    # this endpoint does not have pagination support
    url = "https://api.convertkit.com/v3/tags?api_secret=#{self.service_integration.backfill_secret}"
    response = Webhookdb::Http.get(url, logger: self.logger)
    data = response.parsed_response
    return data["tags"], nil
  end
end
