class RemoveStoreIdFromSpreePaymentMethods < ActiveRecord::Migration[5.2]
  def change
    remove_column :spree_payment_methods, :store_id, :integer
  end
end
