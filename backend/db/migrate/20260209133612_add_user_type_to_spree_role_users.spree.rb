# This migration comes from spree (originally 20250313104226)
class AddUserTypeToSpreeRoleUsers < ActiveRecord::Migration[6.1]
  def up
    unless column_exists?(:spree_role_users, :user_type)
      add_column :spree_role_users, :user_type, :string
      add_index :spree_role_users, :user_type

      user_class_name = Spree.admin_user_class.to_s
      Spree::RoleUser.where(user_type: nil).update_all(user_type: user_class_name)

      change_column_null :spree_role_users, :user_type, false
    end
  end

  def down
    remove_index :spree_role_users, :user_type, if_exists: true
    remove_column :spree_role_users, :user_type, if_exists: true
  end
end
