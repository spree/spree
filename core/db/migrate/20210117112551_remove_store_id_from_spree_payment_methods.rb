class RemoveStoreIdFromSpreePaymentMethods < ActiveRecord::Migration[6.0]
  def change
    remove_column :spree_payment_methods, :store_id, :integer
  end
end
