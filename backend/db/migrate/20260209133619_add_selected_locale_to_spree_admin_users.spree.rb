# This migration comes from spree (originally 20250508060800)
class AddSelectedLocaleToSpreeAdminUsers < ActiveRecord::Migration[7.2]
  def change
    if Spree.admin_user_class.present?
      users_table_name = Spree.admin_user_class.table_name
      add_column users_table_name, :selected_locale, :string unless column_exists?(users_table_name, :selected_locale)
    end
  end
end
