class AddStoreIdToPaymentMethods < ActiveRecord::Migration[5.2]
  def change
    add_column :spree_payment_methods, :store_id, :integer unless column_exists?(:spree_payment_methods, :store_id)
  end
end
