class UpdateOrderState < ActiveRecord::Migration
  def self.up
    Spree::Order.table_name = "orders"

    Spree::Order.all.map(&:update!)

    Spree::Order.table_name = "spree_orders"
  end

  def self.down
  end
end