# This migration comes from spree (originally 20250418174652)
class AddResourceToSpreeRoleUsers < ActiveRecord::Migration[7.2]
  def change
    add_reference :spree_role_users, :resource, polymorphic: true, null: true
    add_reference :spree_role_users, :invitation, null: true

    add_index :spree_role_users, [:resource_id, :resource_type, :user_id, :user_type, :role_id], unique: true
  end
end
