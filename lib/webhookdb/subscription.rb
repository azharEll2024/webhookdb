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
    subscription_obj = Stripe::Subscription.retrieve(id)
    self.create_or_update_from_stripe_hash(subscription_obj.as_json)
  end

  def self.status_for_org(org)
    service_integrations = org.service_integrations.reject(&:soft_deleted?)
    used = service_integrations.count
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

  def self.backfill_from_stripe(limit: 50, page_size: 50)
    subs = Stripe::Subscription.list({limit: page_size})
    done = 0
    subs.auto_paging_each do |sub|
      self.create_or_update_from_stripe_hash(sub.as_json)
      done += 1
      break if !limit.nil? && done >= limit
    end
  end
end

# Table: subscriptions
# ---------------------------------------------------------------------------------------------
# Columns:
#  id                 | integer                  | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  created_at         | timestamp with time zone | NOT NULL DEFAULT now()
#  updated_at         | timestamp with time zone |
#  soft_deleted_at    | timestamp with time zone |
#  stripe_id          | text                     | NOT NULL
#  stripe_customer_id | text                     | NOT NULL DEFAULT ''::text
#  stripe_json        | jsonb                    | DEFAULT '{}'::jsonb
# Indexes:
#  subscriptions_pkey                   | PRIMARY KEY btree (id)
#  subscriptions_stripe_customer_id_key | UNIQUE btree (stripe_customer_id)
#  subscriptions_stripe_id_key          | UNIQUE btree (stripe_id)
# ---------------------------------------------------------------------------------------------
