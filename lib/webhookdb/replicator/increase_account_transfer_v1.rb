# frozen_string_literal: true

require "webhookdb/increase"
require "webhookdb/replicator/increase_v1_mixin"

class Webhookdb::Replicator::IncreaseAccountTransferV1 < Webhookdb::Replicator::Base
  include Appydays::Loggable
  include Webhookdb::Replicator::IncreaseV1Mixin

  # @return [Webhookdb::Replicator::Descriptor]
  def self.descriptor
    return Webhookdb::Replicator::Descriptor.new(
      name: "increase_account_transfer_v1",
      ctor: ->(sint) { Webhookdb::Replicator::IncreaseAccountTransferV1.new(sint) },
      feature_roles: [],
      resource_name_singular: "Increase Account Transfer",
      supports_webhooks: true,
      supports_backfill: true,
    )
  end

  def _remote_key_column
    return Webhookdb::Replicator::Column.new(:increase_id, TEXT, data_key: "id")
  end

  def _denormalized_columns
    return [
      Webhookdb::Replicator::Column.new(:amount, INTEGER, index: true),
      Webhookdb::Replicator::Column.new(:account_id, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:canceled_at, TIMESTAMP, data_key: ["cancellation", "canceled_at"],
                                                                 optional: true,),
      Webhookdb::Replicator::Column.new(:created_at, TIMESTAMP, index: true),
      Webhookdb::Replicator::Column.new(:destination_account_id, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:destination_transaction_id, TEXT, index: true),
      Webhookdb::Replicator::Column.new(:status, TEXT),
      Webhookdb::Replicator::Column.new(:template_id, TEXT),
      Webhookdb::Replicator::Column.new(:transaction_id, TEXT, index: true),
      Webhookdb::Replicator::Column.new(
        :updated_at,
        TIMESTAMP,
        data_key: "created_at",
        event_key: "created_at",
        defaulter: :now,
        index: true,
      ),
    ]
  end

  def _update_where_expr
    return self.qualified_table_sequel_identifier[:updated_at] < Sequel[:excluded][:updated_at]
  end

  def _resource_and_event(request)
    return self._find_resource_and_event(request.body, "account_transfer")
  end

  def _mixin_backfill_url
    return "#{self.service_integration.api_url}/account_transfers"
  end
end
