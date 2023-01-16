class ChangeProductNameNullToTrue < ActiveRecord::Migration[6.1]
  def change
    change_column_null :spree_products, :name, true
  end
end
