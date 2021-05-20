class AddNewOrderNotificationsEmailToSpreeStores < ActiveRecord::Migration[5.2]
  def change
    unless column_exists?(:spree_stores, :new_order_notifications_email)
      add_column :spree_stores, :new_order_notifications_email, :string
    end
  end
end
