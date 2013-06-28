class AddUniqueIndexToOrdersShipmentsAndStockTransfers < ActiveRecord::Migration
  def add
    add_index "spree_orders", ["number"], :name => "number_idx_unique", :unique => true
    add_index "spree_shipments", ["number"], :name => "number_idx_unique", :unique => true
    add_index "spree_stock_transfers", ["number"], :name => "number_idx_unique", :unique => true
  end
end
