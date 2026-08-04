class AddFirstNameAndLastNameToSpreeUsers < ActiveRecord::Migration[5.2]
  def change
    return unless Spree.customer_class.present?

    table = Spree.customer_class.table_name
    return unless table_exists?(table)

    add_column table, :first_name, :string unless column_exists?(table, :first_name)
    add_column table, :last_name, :string unless column_exists?(table, :last_name)
  end
end
