class RemoveStoreIdFromSpreePaymentMethods < ActiveRecord::Migration[6.0]
  def up
    Spree::PaymentMethod.all.each do |payment_method|
      next if payment_method.store_ids.any?

      payment_method.store_ids = if payment_method[:store_id].present?
        payment_method[:store_id]
      else
        Spree::Store.ids
      end

      payment_method.save
    end
  end

  def change
    remove_column :spree_payment_methods, :store_id
  end
end
