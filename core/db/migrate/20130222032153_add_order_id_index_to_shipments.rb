class AddOrderIdIndexToShipments < ActiveRecord::Migration
  def change
    add_index :spree_shipments, :order_id
  end
end
