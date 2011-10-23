class UpdateOrderState < ActiveRecord::Migration
  def self.up
    Spree::Order.all.map(&:update!)
  end

  def self.down
  end
end
