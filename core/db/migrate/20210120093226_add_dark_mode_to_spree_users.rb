class AddDarkModeToSpreeUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :spree_users, :dark_mode, :boolean, default: false
  end
end
