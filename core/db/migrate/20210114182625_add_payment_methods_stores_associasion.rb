class AddPaymentMethodsStoresAssociasion < ActiveRecord::Migration[6.0]
  def change
    create_table :spree_payment_methods_stores, id: false do |t|
      t.belongs_to :payment_method
      t.belongs_to :store
    end
  end
end
