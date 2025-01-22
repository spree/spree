class AddFirstAndLastNameToSpreeAdminClass < ActiveRecord::Migration[7.2]
  def change
    if Spree.admin_user_class.present?
      admin_users_table_name = Spree.admin_user_class.table_name
      add_column admin_users_table_name, :first_name, :string unless column_exists?(admin_users_table_name, :first_name)
      add_column admin_users_table_name, :last_name, :string unless column_exists?(admin_users_table_name, :last_name)
    end
  end
end
