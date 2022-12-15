class AddSelectedLocaleToSpreeUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :spree_users, :selected_locale, :string
  end
end
