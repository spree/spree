class RenameGuestTokenToTokenInOrders < ActiveRecord::Migration[5.2]
  def change
    rename_column :spree_orders, :guest_token, :token
  end
end
