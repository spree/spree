class AddSelectedLocaleToSpreeUsers < ActiveRecord::Migration[7.0]
  def change
    if Spree.user_class.present?
      users_table_name = Spree.user_class.table_name
      add_column users_table_name, :selected_locale, :string unless column_exists?(users_table_name, :selected_locale)
    end
  end
end
