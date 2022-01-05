# frozen_string_literal: true

require "webhookdb/postgres/model"

class Webhookdb::Role < Webhookdb::Postgres::Model(:roles)
  # n.b. Because of the uniqueness constraint on "name", there is only one "admin" role. Its meaning
  # depends on the context: if the customer has this role, they are an admin; if the org membership has
  # this role, the customer is an org admin.
  def self.admin_role
    return Webhookdb.cached_get("role_admin") do
      self.find_or_create_or_find(name: "admin")
    end
  end

  # used to indicate user status within the org, e.g. whether user is an org admin & can create services
  one_to_many :organization_memberships, class: "Webhookdb::OrganizationMembership"

  # used to indicate user status within the app itself, i.e. whether user is an app admin
  many_to_many :customers,
               class: "Webhookdb::Customer",
               join_table: :roles_customers
end

# Table: roles
# ---------------------------------------------------------------------------------------------------------------------------
# Columns:
#  id   | integer | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  name | text    | NOT NULL
# Indexes:
#  roles_pkey     | PRIMARY KEY btree (id)
#  roles_name_key | UNIQUE btree (name)
# Referenced By:
#  feature_roles_organizations | feature_roles_organizations_role_id_fkey         | (role_id) REFERENCES roles(id)
#  organization_memberships    | organization_memberships_membership_role_id_fkey | (membership_role_id) REFERENCES roles(id)
#  roles_customers             | roles_customers_role_id_fkey                     | (role_id) REFERENCES roles(id)
# ---------------------------------------------------------------------------------------------------------------------------
