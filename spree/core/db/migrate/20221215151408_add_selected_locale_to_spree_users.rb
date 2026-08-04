class AddSelectedLocaleToSpreeUsers < ActiveRecord::Migration[6.1]
  def change
    return unless Spree.customer_class.present?

    table = Spree.customer_class.table_name
    return unless table_exists?(table)

    add_column table, :selected_locale, :string unless column_exists?(table, :selected_locale)
  end
end
