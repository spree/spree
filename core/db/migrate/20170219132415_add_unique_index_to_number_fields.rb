class AddUniqueIndexToNumberFields < ActiveRecord::Migration
  def change
    remove_index :spree_orders, :number
    add_index :spree_orders, :number, :unique => true
    remove_index :spree_payments, name: :index_spree_payments_on_number if index_name_exists?(:spree_payments, :index_spree_payments_on_number, nil)
    add_index :spree_payments, :number, :unique => true
    add_index :spree_reimbursements, :number, :unique => true
    add_index :spree_return_authorizations, :number, :unique => true
    remove_index :spree_shipments, name: :index_shipments_on_number if index_name_exists?(:spree_shipments, :index_shipments_on_number, nil)
    add_index :spree_shipments, :number, :unique => true
    remove_index :spree_stock_transfers, :number if index_exists?(:spree_stock_transfers, :number)
    add_index :spree_stock_transfers, :number, :unique => true
  end
end
