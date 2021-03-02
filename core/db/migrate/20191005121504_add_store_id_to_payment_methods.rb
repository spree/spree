class AddStoreIdToPaymentMethods < ActiveRecord::Migration[5.2]
  def change
    unless column_exists?(:spree_payment_methods, :store_id)
      add_reference :spree_payment_methods, :store, references: :spree_stores, index: true
    end
  end
end
