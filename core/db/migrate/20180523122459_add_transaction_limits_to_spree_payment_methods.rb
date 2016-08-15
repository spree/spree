class AddTransactionLimitsToSpreePaymentMethods < ActiveRecord::Migration[5.1]
  def change
    add_column :spree_payment_methods, :transaction_minimum, :decimal, precision: 8, scale: 2, null: true
    add_column :spree_payment_methods, :transaction_maximum, :decimal, precision: 8, scale: 2, null: true
  end
end
