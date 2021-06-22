# frozen_string_literal: true

require "webhookdb/postgres/model"
require "appydays/configurable"

class Webhookdb::Organization < Webhookdb::Postgres::Model(:organizations)
  plugin :timestamps
  plugin :soft_deletes

  configurable(:organization) do
    setting :max_query_rows, 1000
  end

  one_to_many :memberships, class: "Webhookdb::OrganizationMembership"
  one_to_many :service_integrations, class: "Webhookdb::ServiceIntegration"

  def before_create
    self.key ||= Webhookdb.to_slug(self.name)
    super
  end

  def before_save
    self.key ||= Webhookdb.to_slug(self.name)
    super
  end

  def self.create_if_unique(params)
    self.db.transaction(savepoint: true) do
      return Webhookdb::Organization.create(name: params[:name])
    end
  rescue Sequel::UniqueConstraintViolation
    return nil
  end

  def cli_editable_fields
    return ["name", "billing_email"]
  end

  def self.lookup_by_identifier(identifier)
    # Check to see if identifier is an integer, i.e. an ID.
    # Otherwise treat it as a slug
    org = if /\A\d+\z/.match?(identifier)
            Webhookdb::Organization[id: identifier]
          else
            Webhookdb::Organization[key: identifier]
          end
    return org
  end

  def execute_readonly_query(sql)
    return Webhookdb::ConnectionCache.borrow(self.readonly_connection_url) do |conn|
      ds = conn.fetch(sql)
      r = QueryResult.new
      r.columns = ds.columns
      r.rows = []
      ds.each do |row|
        if r.rows.length >= self.class.max_query_rows
          r.max_rows_reached = true
          break
        end
        r.rows << row.values
      end
      return r
    end
  end

  class QueryResult
    attr_accessor :rows, :columns, :max_rows_reached
  end

  def dbname
    raise Webhookdb::InvalidPrecondition, "no db has been created, call prepare_database_connections first" if
      self.admin_connection_url.blank?
    return URI(self.admin_connection_url).path.tr("/", "")
  end

  def admin_user
    ur = URI(self.admin_connection_url)
    return ur.user
  end

  def readonly_user
    ur = URI(self.readonly_connection_url)
    return ur.user
  end

  def prepare_database_connections
    self.db.transaction do
      self.lock!
      raise Webhookdb::InvalidPrecondition, "connections already set" if self.admin_connection_url.present?
      builder = Webhookdb::Organization::DbBuilder.prepare_database_connections(self)
      self.admin_connection_url = builder.admin_url
      self.readonly_connection_url = builder.readonly_url
      self.save_changes
    end
  end

  def remove_related_database
    self.db.transaction do
      self.lock!
      Webhookdb::Organization::DbBuilder.remove_related_database(self)
      self.admin_connection_url = ""
      self.readonly_connection_url = ""
      self.save_changes
    end
  end

  def validate
    super
    validates_all_or_none(:admin_connection_url, :readonly_connection_url)
  end
end

require "webhookdb/organization/db_builder"

# TODO: Remove readwrite url, just use admin

# Table: organizations
# --------------------------------------------------------------------------------------------------------------------------
# Columns:
#  id                       | integer                  | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  created_at               | timestamp with time zone | NOT NULL DEFAULT now()
#  updated_at               | timestamp with time zone |
#  soft_deleted_at          | timestamp with time zone |
#  name                     | text                     | NOT NULL
#  key                      | text                     |
#  readonly_connection_url  | text                     |
#  readwrite_connection_url | text                     |
#  admin_connection_url     | text                     |
# Indexes:
#  organizations_pkey     | PRIMARY KEY btree (id)
#  organizations_key_key  | UNIQUE btree (key)
#  organizations_name_key | UNIQUE btree (name)
# Referenced By:
#  organization_memberships | organization_memberships_organization_id_fkey | (organization_id) REFERENCES organizations(id)
#  service_integrations     | service_integrations_organization_id_fkey     | (organization_id) REFERENCES organizations(id)
# --------------------------------------------------------------------------------------------------------------------------
