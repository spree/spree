class AddUniqueIndexToSpreePaymentsResponseCode < ActiveRecord::Migration[7.2]
  def up
    # Remove duplicate payments per (order, payment_method, response_code),
    # keeping the one with the highest id (most recent).
    # Uses derived table for MySQL compatibility.
    execute <<~SQL
      DELETE FROM spree_payments
      WHERE response_code IS NOT NULL
        AND id NOT IN (
          SELECT max_id FROM (
            SELECT MAX(id) AS max_id
            FROM spree_payments
            WHERE response_code IS NOT NULL
            GROUP BY order_id, payment_method_id, response_code
          ) AS keeper_ids
        )
    SQL

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

  def down
    remove_index :spree_payments, name: 'idx_payments_order_method_response_code'
  end
end
