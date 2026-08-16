class AddStoreIdToSpreeRoleUsers < ActiveRecord::Migration[7.2]
  def change
    # Denormalizes the store a role assignment applies within, so role
    # resolution (Spree::Ability) can scope by store without depending on the
    # polymorphic resource. Kept null: true here.
    #
    # Superseded in 6.0: the role itself names what it governs, so this column
    # and the assignment's own resource are both dropped by
    # AddResourceToSpreeRoles, which reads them one last time to decide which
    # role each grant belongs to.
    add_reference :spree_role_users, :store, null: true
  end
end
