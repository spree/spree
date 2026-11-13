class AddGiftMessageToCartsAndOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_carts, :gift_message, :text
    add_column :spree_orders, :gift_message, :text
  end
end
