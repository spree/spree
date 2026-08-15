class AddStoreToSpreeRoles < ActiveRecord::Migration[8.1]
  # Roles become store-owned. They were global reference data, which meant two
  # stores on one installation could never each define a "Manager" — and the
  # marketplace work makes that worse, since vendor tiers are defined by the
  # operator of a particular store.
  #
  # Existing rows are duplicated once per store and their assignments
  # re-pointed at the copy for the store they were already bound to, so no
  # grant changes hands. `spree_role_users.store_id` is the source of truth for
  # who held what where — it has been there all along.
  class MigrationRole < ActiveRecord::Base
    self.table_name = 'spree_roles'
  end

  class MigrationRoleUser < ActiveRecord::Base
    self.table_name = 'spree_role_users'
  end

  class MigrationInvitation < ActiveRecord::Base
    self.table_name = 'spree_invitations'
  end

  class MigrationStore < ActiveRecord::Base
    self.table_name = 'spree_stores'
  end

  def up
    add_column :spree_roles, :store_id, :bigint

    MigrationRole.reset_column_information
    fan_out_roles_per_store

    change_column_null :spree_roles, :store_id, false
    add_index :spree_roles, :store_id

    remove_index :spree_roles, :name, unique: true
    add_index :spree_roles, [:store_id, :name, :audience], unique: true,
                                                           name: 'index_spree_roles_on_store_and_name_and_audience'
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # Gives every store its own copy of each role, then re-points assignments and
  # invitations at the copy belonging to the store they name. The original row
  # is kept for the first store so ids stay stable for anything already
  # referencing them.
  def fan_out_roles_per_store
    store_ids = MigrationStore.order(:id).pluck(:id)
    return if store_ids.empty?

    primary_store_id, *other_store_ids = store_ids

    MigrationRole.where(store_id: nil).find_each do |role|
      MigrationRole.where(id: role.id).update_all(store_id: primary_store_id)

      other_store_ids.each do |store_id|
        copy_id = duplicate_role(role, store_id)
        repoint_grants(role.id, copy_id, store_id)
      end
    end
  end

  def duplicate_role(role, store_id)
    attributes = role.attributes.except('id').merge('store_id' => store_id)
    MigrationRole.insert(attributes)
    MigrationRole.where(store_id: store_id, name: role.name).pick(:id)
  end

  # Assignments carry `store_id` directly. Invitations reach their store
  # through the polymorphic resource, so only store-resourced ones can be
  # placed here — an invitation to any other resource keeps the primary
  # store's role, which is the same row it already pointed at.
  def repoint_grants(original_role_id, copy_role_id, store_id)
    MigrationRoleUser.where(role_id: original_role_id, store_id: store_id).update_all(role_id: copy_role_id)

    MigrationInvitation.
      where(role_id: original_role_id, resource_type: 'Spree::Store', resource_id: store_id).
      update_all(role_id: copy_role_id)
  end
end
