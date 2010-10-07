class PaymentTotalForOrders < ActiveRecord::Migration
  def self.up
    add_column :orders, :payment_total, :decimal, :precision => 8, :scale => 2, :default => 0.0
  end

  def self.down
    remove_column :orders, :payment_total
  end
end
