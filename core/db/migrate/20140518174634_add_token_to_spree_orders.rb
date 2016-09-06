class AddTokenToSpreeOrders < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_orders, :guest_token, :string
  end
end
