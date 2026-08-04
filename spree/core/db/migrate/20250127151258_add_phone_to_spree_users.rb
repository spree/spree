class AddPhoneToSpreeUsers < ActiveRecord::Migration[6.1]
  def change
    return unless Spree.customer_class.present? && table_exists?(Spree.customer_class.table_name)

    add_column Spree.customer_class.table_name, :phone, :string, if_not_exists: true
  end
end
