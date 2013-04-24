class AddBackorderableToStockItem < ActiveRecord::Migration
  def change
    add_column :spree_stock_items, :backorderable, :boolean, :default => true
  end
end
