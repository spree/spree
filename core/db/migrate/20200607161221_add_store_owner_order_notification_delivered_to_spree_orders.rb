class AddStoreOwnerOrderNotificationDeliveredToSpreeOrders < ActiveRecord::Migration[6.0]
  def change
    add_column :spree_orders, :store_owner_notification_delivered, :boolean, default: false
  end
end
