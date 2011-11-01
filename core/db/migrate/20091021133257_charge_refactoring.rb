class Checkout < ActiveRecord::Base; end;

# Hack to prevent issues with legacy migrations
class Order < ActiveRecord::Base
  has_one :checkout
end

class ChargeRefactoring < ActiveRecord::Migration
  def self.up
    add_column :orders, :completed_at, :timestamp
    Order.reset_column_information
    Order.all.each {|o| o.update_attribute(:completed_at, o.checkout && o.checkout.read_attribute(:completed_at)) }
    remove_column :checkouts, :completed_at

    change_column :adjustments, :amount, :decimal, :null => true, :default => nil, :precision => 8, :scale => 2
    Spree::Adjustment.update_all "type = secondary_type"
    Spree::Adjustment.update_all "type = 'CouponCredit'", "type = 'Credit'"
    remove_column :adjustments, :secondary_type
  end

  def self.down
    add_column :checkouts, :completed_at, :timestamp
    Spree::Checkout.reset_column_information
    Spree::Checkout.all.each{|c| c.update_attribute(:completed_at, c.order && c.order.completed_at)}
    remove_column :orders, :completed_at

    add_column :adjustments, :secondary_type, :string
    Spree::Adjustment.update_all "secondary_type = type"
    Spree::Adjustment.update_all "type = 'Charge'", "type like '%Charge'"
    Spree::Adjustment.update_all "type = 'Credit'", "type like '%Credit'"
    change_column :adjustments, :amount, :decimal, :null => false, :default => 0, :precision => 8, :scale => 2
  end
end
