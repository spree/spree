# This migration comes from spree (originally 20220201103922)
class AddFirstNameAndLastNameToSpreeUsers < ActiveRecord::Migration[5.2]
  def change
    if Spree.user_class.present?
      users_table_name = Spree.user_class.table_name
      add_column users_table_name, :first_name, :string unless column_exists?(users_table_name, :first_name)
      add_column users_table_name, :last_name, :string unless column_exists?(users_table_name, :last_name)
    end
  end
end
