# frozen_string_literal: true

class Webhookdb::Subscription < Webhookdb::Postgres::Model(:subscriptions)
  extend Webhookdb::MethodUtilities
  include Appydays::Configurable
  include Appydays::Loggable

  plugin :timestamps
  plugin :soft_deletes

  configurable(:subscriptions) do
    setting :max_free_integrations, 2
    setting :paid_plan_stripe_price_id, "lithic_stripe_paid_plan_price"
  end

  def initialize(*)
    super
    self[:stripe_json] ||= Sequel.pg_json({})
  end

  def status
    return self.stripe_json["status"]
  end

  def self.create_or_update_from_stripe_hash(obj)
    sub = self.update_or_create(stripe_id: obj.fetch("id")) do |o|
      o.stripe_json = obj.to_json
      o.stripe_customer_id = obj.fetch("customer")
    end
    return sub
  end

  def self.create_or_update_from_webhook(webhook_body)
    obj = webhook_body["data"]["object"]
    self.create_or_update_from_stripe_hash(obj)
  end

  def self.create_or_update_from_id(id)
    subscription_obj = Stripe::Subscription.retrieve(id, {api_key: Webhookdb::Stripe.api_key})
    self.create_or_update_from_stripe_hash(subscription_obj.as_json)
  end

  def self.status_for_org(org)
    used = org.service_integrations.count
    data = {
      org_name: org.name,
      billing_email: org.billing_email,
      integrations_used: used,
    }
    subscription = Webhookdb::Subscription[stripe_customer_id: org.stripe_customer_id]
    if subscription.nil?
      data[:plan_name] = "Free"
      data[:integrations_left] = [0, Webhookdb::Subscription.max_free_integrations - used].max
      data[:integrations_left_display] = data[:integrations_left].to_s
      data[:sub_status] = ""
    else
      data[:plan_name] = "Premium"
      data[:integrations_left] = 2_000_000_000
      data[:integrations_left_display] = "unlimited"
      data[:sub_status] = subscription.status
    end
    return data
  end
end
