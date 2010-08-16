class ShippingMethodIdForOrders < ActiveRecord::Migration
  def self.up
    add_column :orders, :shipping_method_id, :integer 
  end

  def self.down
    remove_column :orders, :shipping_method_id
  end
end
