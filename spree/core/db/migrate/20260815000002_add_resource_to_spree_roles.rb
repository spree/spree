class AddResourceToSpreeRoles < ActiveRecord::Migration[8.1]
  # A role now names what it governs: a Spree::Store for back-office staff, a
  # Spree::Vendor for a marketplace seller. That one fact replaces two — roles
  # were global, so nothing said which store owned a definition, and nothing
  # said which panel a role belonged to.
  #
  # Assignments lose their own copy of that answer. `spree_role_users` carried
  # `resource` and `store_id`, both of which the role now supplies, so an
  # assignment is reduced to "this user holds this role".
  #
  # The fan-out keys on assignments rather than roles: a bare
  # `role_users.create!` used to bind whichever store was current, so one role
  # row can legitimately be held on several stores. Each distinct pairing
  # becomes its own role.
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
    add_reference :spree_roles, :resource, polymorphic: true, index: false

    MigrationRole.reset_column_information
    fan_out_roles_per_resource
    adopt_orphan_roles

    change_column_null :spree_roles, :resource_id, false
    change_column_null :spree_roles, :resource_type, false

    remove_index :spree_roles, :name, unique: true
    add_index :spree_roles, %i[resource_type resource_id name], unique: true,
                                                                name: 'index_spree_roles_on_resource_and_name'

    dedupe_assignments
    remove_index :spree_role_users, name: 'index_spree_role_users_on_resource'
    remove_column :spree_role_users, :resource_id
    remove_column :spree_role_users, :resource_type
    remove_column :spree_role_users, :store_id
    add_index :spree_role_users, %i[user_type user_id role_id], unique: true,
                                                                name: 'index_spree_role_users_on_user_and_role'
  end

  # Dropping the columns discards which resource each grant applied to, and
  # re-running `up` would have nothing left to fan out.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # Every (role, resource) pairing an assignment or invitation names becomes a
  # role of its own, and the rows that named it are re-pointed at it. The first
  # pairing keeps the original row so existing ids stay valid.
  def fan_out_roles_per_resource
    MigrationRole.where(resource_id: nil).find_each do |role|
      pairings = resource_pairings_for(role)
      next if pairings.empty?

      primary, *rest = pairings
      claim_role(role.id, primary)

      rest.each { |pairing| repoint(role, pairing) }
    end
  end

  # Distinct resources this role is currently granted on, from both the
  # assignments and any pending invitations.
  def resource_pairings_for(role)
    assigned = MigrationRoleUser.where(role_id: role.id).
               where.not(resource_id: nil).
               distinct.pluck(:resource_type, :resource_id)

    invited = MigrationInvitation.where(role_id: role.id).
              where.not(resource_id: nil).
              distinct.pluck(:resource_type, :resource_id)

    (assigned | invited).sort
  end

  def claim_role(role_id, (resource_type, resource_id))
    MigrationRole.where(id: role_id).update_all(resource_type: resource_type, resource_id: resource_id)
  end

  def repoint(role, pairing)
    resource_type, resource_id = pairing
    copy_id = duplicate_role(role, pairing)

    MigrationRoleUser.where(role_id: role.id, resource_type: resource_type, resource_id: resource_id).
      update_all(role_id: copy_id)
    MigrationInvitation.where(role_id: role.id, resource_type: resource_type, resource_id: resource_id).
      update_all(role_id: copy_id)
  end

  # Reuses a same-named role already owned by that resource rather than
  # creating a second one, since names are unique per resource.
  def duplicate_role(role, (resource_type, resource_id))
    existing = MigrationRole.where(resource_type: resource_type, resource_id: resource_id, name: role.name).pick(:id)
    return existing if existing

    attributes = role.attributes.except('id').merge(
      'resource_type' => resource_type, 'resource_id' => resource_id
    )
    MigrationRole.insert(attributes)
    MigrationRole.where(resource_type: resource_type, resource_id: resource_id, name: role.name).pick(:id)
  end

  # Roles nobody holds have no resource to infer, so they go to the first store
  # — the same store a bare assignment would have bound them to.
  def adopt_orphan_roles
    primary_store_id = MigrationStore.order(:id).pick(:id)
    return if primary_store_id.nil?

    MigrationRole.where(resource_id: nil).find_each do |role|
      taken = MigrationRole.where(resource_type: 'Spree::Store', resource_id: primary_store_id, name: role.name)
      next MigrationRole.where(id: role.id).delete_all if taken.exists?

      MigrationRole.where(id: role.id).update_all(resource_type: 'Spree::Store', resource_id: primary_store_id)
    end
  end

  # The old unique index spanned the resource, so one user could hold one role
  # on several of them. Those rows collapse into one.
  def dedupe_assignments
    duplicates = MigrationRoleUser.group(:user_type, :user_id, :role_id).having('COUNT(*) > 1').count

    duplicates.each_key do |user_type, user_id, role_id|
      keeper = MigrationRoleUser.where(user_type: user_type, user_id: user_id, role_id: role_id).minimum(:id)
      MigrationRoleUser.where(user_type: user_type, user_id: user_id, role_id: role_id).
        where.not(id: keeper).delete_all
    end
  end
end
