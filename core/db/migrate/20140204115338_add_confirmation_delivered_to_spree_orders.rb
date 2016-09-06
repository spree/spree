class AddConfirmationDeliveredToSpreeOrders < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_orders, :confirmation_delivered, :boolean, default: false
  end
end
