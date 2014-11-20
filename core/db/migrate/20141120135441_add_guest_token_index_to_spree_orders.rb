class AddGuestTokenIndexToSpreeOrders < ActiveRecord::Migration
  def change
    add_index :spree_orders, :guest_token
  end
end
