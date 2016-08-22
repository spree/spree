class SetBackorderableToDefaultToFalse < ActiveRecord::Migration[4.2]
  def change
    change_column :spree_stock_items, :backorderable, :boolean, default: false
    change_column :spree_stock_locations, :backorderable_default, :boolean, default: false
  end
end
