class ChangeProductNameNullToTrue < ActiveRecord::Migration[7.0]
  def change
    change_column_null :spree_products, :name, true
  end
end
