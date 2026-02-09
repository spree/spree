# This migration comes from spree (originally 20250127151258)
class AddPhoneToSpreeUsers < ActiveRecord::Migration[6.1]
  def change
    add_column Spree.user_class.table_name, :phone, :string, if_not_exists: true
  end
end
