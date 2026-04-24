class AddUniqueIndexToSpreePaymentsResponseCode < ActiveRecord::Migration[7.2]
  def change
    if ActiveRecord::Base.connection.adapter_name == 'Mysql2'
      # MySQL doesn't support partial indexes, but treats NULL as distinct
      # in unique indexes so multiple payments with NULL response_code are allowed
      add_index :spree_payments, [:order_id, :payment_method_id, :response_code],
                unique: true,
                name: 'idx_payments_order_method_response_code'
    else
      add_index :spree_payments, [:order_id, :payment_method_id, :response_code],
                unique: true,
                where: 'response_code IS NOT NULL',
                name: 'idx_payments_order_method_response_code'
    end
  end
end
