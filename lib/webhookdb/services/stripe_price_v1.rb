# frozen_string_literal: true

require "stripe"
require "webhookdb/services/stripe_v1_mixin"

class Webhookdb::Services::StripePriceV1 < Webhookdb::Services::Base
  include Appydays::Loggable
  include Webhookdb::Services::StripeV1Mixin

  # @return [Webhookdb::Services::Descriptor]
  def self.descriptor
    return Webhookdb::Services::Descriptor.new(
      name: "stripe_price_v1",
      ctor: ->(sint) { Webhookdb::Services::StripePriceV1.new(sint) },
      feature_roles: [],
    )
  end

  def _remote_key_column
    return Webhookdb::Services::Column.new(:stripe_id, "text")
  end

  def _denormalized_columns
    return [
      Webhookdb::Services::Column.new(:created, "timestamptz"),
      Webhookdb::Services::Column.new(:product, "text"),
      Webhookdb::Services::Column.new(:interval, "text"),
      Webhookdb::Services::Column.new(:type, "text"),
      Webhookdb::Services::Column.new(:unit_amount, "text"),
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
      created: self.tsat(obj_of_interest.fetch("created")),
      product: obj_of_interest.fetch("product"),
      interval: obj_of_interest.fetch("recurring").fetch("interval"),
      type: obj_of_interest.fetch("type"),
      unit_amount: obj_of_interest.fetch("unit_amount"),
      updated: self.tsat(updated),
      stripe_id: obj_of_interest.fetch("id"),
    }
  end

  def _mixin_name_singular
    return "Stripe Price"
  end

  def _mixin_name_plural
    return "Stripe Prices"
  end

  def _mixin_backfill_url
    return "https://api.stripe.com/v1/prices"
  end

  def _mixin_event_type_names
    return [
      "price.created",
      "price.deleted",
      "price.updated",
    ]
  end
end
