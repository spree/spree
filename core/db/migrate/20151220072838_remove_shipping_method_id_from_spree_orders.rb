class RemoveShippingMethodIdFromSpreeOrders < ActiveRecord::Migration
  def up
    if column_exists?(:spree_orders, :shipping_method_id, :integer)
      remove_column :spree_orders, :shipping_method_id, :integer
    end
  end

  def down
    unless column_exists?(:spree_orders, :shipping_method_id, :integer)
      add_column :spree_orders, :shipping_method_id, :integer
    end
  end
end
