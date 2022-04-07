# frozen_string_literal: true

require "stripe"
require "webhookdb/services/stripe_v1_mixin"

class Webhookdb::Services::StripeDisputeV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::StripeV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "stripe_dispute_v1",
      ctor: ->(sint) { Webhookdb::Services::StripeDisputeV1.new(sint) },
      feature_roles: [],
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:amount, "integer"),
      Webhookdb::Services::Column.new(:charge, "text"),
      Webhookdb::Services::Column.new(:created, "timestamptz"),
      Webhookdb::Services::Column.new(:cancellation_policy, "text"),
      Webhookdb::Services::Column.new(:receipt, "text"),
      Webhookdb::Services::Column.new(:refund_policy, "text"),
      Webhookdb::Services::Column.new(:service_date, "timestamptz"),
      Webhookdb::Services::Column.new(:due_by, "timestamptz"),
      Webhookdb::Services::Column.new(:is_charge_refundable, "text"),
      Webhookdb::Services::Column.new(:status, "text"),
      Webhookdb::Services::Column.new(:updated, "timestamptz"),
    ]
  end

  def _update_where_expr
    return Sequel[self.table_sym][:updated] < Sequel[:excluded][:updated]
  end

  def _prepare_for_insert(body, **_kwargs)
    obj_of_interest, updated = self._extract_obj_and_updated(body)
    return {
      data: obj_of_interest.to_json,
      amount: obj_of_interest.fetch("amount"),
      charge: obj_of_interest.fetch("charge"),
      created: self.tsat(obj_of_interest.fetch("created")),
      cancellation_policy: obj_of_interest.fetch("evidence").fetch("cancellation_policy"),
      receipt: obj_of_interest.fetch("evidence").fetch("receipt"),
      refund_policy: obj_of_interest.fetch("evidence").fetch("refund_policy"),
      service_date: self.tsat(obj_of_interest.fetch("evidence").fetch("service_date")),
      due_by: self.tsat(obj_of_interest.fetch("evidence_details").fetch("due_by")),
      is_charge_refundable: obj_of_interest.fetch("is_charge_refundable"),
      status: obj_of_interest.fetch("status"),
      updated: self.tsat(updated),
      stripe_id: obj_of_interest.fetch("id"),
    }
  end

  def _mixin_name_singular
    return "Stripe Dispute"
  end

  def _mixin_name_plural
    return "Stripe Disputes"
  end

  def _mixin_backfill_url
    return "https://api.stripe.com/v1/disputes"
  end

  def _mixin_event_type_names
    return [
      "charge.dispute.closed",
      "charge.dispute.created",
      "charge.dispute.funds_reinstated",
      "charge.dispute.funds_withdrawn",
      "charge.dispute.updated",
    ]
  end
end