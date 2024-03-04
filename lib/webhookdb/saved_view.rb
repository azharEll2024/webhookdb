# frozen_string_literal: true

class Webhookdb::SavedView < Webhookdb::Postgres::Model(:saved_views)
  plugin :timestamps
  plugin :text_searchable, terms: [:organization, :created_by]

  DOCS_URL = "https://docs.webhookdb.com/docs/integrating/saved-views.html"

  class InvalidQuery < Webhookdb::InvalidInput; end

  many_to_one :organization, class: "Webhookdb::Organization"
  many_to_one :created_by, class: "Webhookdb::Customer"

  def self.feature_role
    return Webhookdb.cached_get("saved-view-feature-role") do
      Webhookdb::Role.find_or_create_or_find(name: "saved_views")
    end
  end

  def self.create_or_replace(organization:, sql:, name:, **kw)
    Webhookdb::DBAdapter.validate_identifier!(name, type: "view")
    self.db.transaction do
      sv = self.find_or_create_or_find(organization:, name:) do |new|
        new.sql = sql
      end
      sv.update(sql:, **kw)

      # Verify that the underlying query is readonly, by running it as a readonly user.
      if (_, errmsg = organization.execute_readonly_query_with_help(sql)) && errmsg.present?
        raise InvalidQuery, errmsg
      end

      # Create the view now that we've asserted it's readonly
      qname = Webhookdb::DBAdapter::PG.new.escape_identifier(name)
      organization.admin_connection do |conn|
        conn << "CREATE OR REPLACE VIEW #{qname} AS (#{sql})"
      end
      return sv
    end
  end

  def before_destroy
    raise Webhookdb::InvariantViolation, "#{self.inspect} name became invalid somehow" unless
      Webhookdb::DBAdapter.valid_identifier?(self.name)
    if self.organization.admin_connection_url_raw.present?
      qname = Webhookdb::DBAdapter::PG.new.escape_identifier(self.name)
      self.organization.admin_connection do |conn|
        conn << "DROP VIEW IF EXISTS #{qname}"
      end
    end
    super
  end
end

# Table: saved_views
# ----------------------------------------------------------------------------------------------------
# Columns:
#  id              | integer                  | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  created_at      | timestamp with time zone | NOT NULL DEFAULT now()
#  updated_at      | timestamp with time zone |
#  organization_id | integer                  | NOT NULL
#  name            | text                     | NOT NULL
#  sql             | text                     | NOT NULL
#  created_by_id   | integer                  |
#  text_search     | tsvector                 |
# Indexes:
#  saved_views_pkey                     | PRIMARY KEY btree (id)
#  saved_views_organization_id_name_key | UNIQUE btree (organization_id, name)
#  saved_views_organization_id_index    | btree (organization_id)
# Foreign key constraints:
#  saved_views_created_by_id_fkey   | (created_by_id) REFERENCES customers(id) ON DELETE SET NULL
#  saved_views_organization_id_fkey | (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
# ----------------------------------------------------------------------------------------------------
