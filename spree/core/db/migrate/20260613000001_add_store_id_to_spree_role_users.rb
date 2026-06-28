class AddStoreIdToSpreeRoleUsers < ActiveRecord::Migration[7.2]
  def change
    # Denormalizes the store a role assignment applies within, so role
    # resolution (Spree::Ability) can scope by store without depending on the
    # polymorphic resource. Kept null: true here; existing rows are backfilled
    # by `spree:role_users:backfill_store_ids` and presence is enforced
    # on the model.
    add_reference :spree_role_users, :store, null: true
  end
end
