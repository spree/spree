class AddStoreOwnerOrderNotificationDeliveredToSpreeOrders < ActiveRecord::Migration[6.0]
  def change
    unless column_exists?(:spree_orders, :store_owner_notification_delivered)
      add_column :spree_orders, :store_owner_notification_delivered, :boolean
    end
  end
end
