class AddUniqueIndexToSpreePaymentsResponseCode < ActiveRecord::Migration[7.2]
  def change
    add_index :spree_payments, [:order_id, :payment_method_id, :response_code],
              unique: true,
              where: 'response_code IS NOT NULL',
              name: 'idx_payments_order_method_response_code'
  end
end
