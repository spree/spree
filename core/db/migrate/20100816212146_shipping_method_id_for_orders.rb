class ShippingMethodIdForOrders < ActiveRecord::Migration
  def change
    add_column :orders, :shipping_method_id, :integer
  end
end
