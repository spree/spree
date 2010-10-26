class UpdateOrderState < ActiveRecord::Migration
  def self.up
    Order.all.map(&:update!)
  end

  def self.down
  end
end