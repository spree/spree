class CreateSpreePaymentMethodsStores < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_payment_methods_stores, id: false do |t|
      t.belongs_to :payment_method
      t.belongs_to :store
    end

    add_index :spree_payment_methods_stores, [:payment_method_id, :store_id], unique: true, name: 'payment_mentod_id_store_id_unique_index'
  end
end
