class RemoveStoreIdFromSpreePaymentMethods < ActiveRecord::Migration[6.0]

  def up
    Spree::PaymentMethod.all.each do |payment_method|
       if payment_method.store_id.nil?
         Spree::Store.all.each do |store|
           payment_method.store_ids = store.id
           payment_method.save
         end
       else
         payment_method.store_ids = [:store_id]
         payment_method.save
       end
     end
  end

  def change
    remove_column :spree_payment_methods, :store_id, :integer
  end
end
