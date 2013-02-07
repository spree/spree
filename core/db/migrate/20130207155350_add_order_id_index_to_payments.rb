class AddOrderIdIndexToPayments < ActiveRecord::Migration
  def self.up
    add_index :spree_payments, :order_id
  end

  def self.down
    remove_index :spree_payments, :order_id
  end
end
