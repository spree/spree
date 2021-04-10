class AddAdminThemeNameToSpreeUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :spree_users, :admin_theme_name, :string, default: 'Default'
  end
end
