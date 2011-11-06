class Order < ActiveRecord::Base; end;

class PreventNilPaymentTotal < ActiveRecord::Migration
  def self.up
    Order.where(:payment_total => nil).update_all(:payment_total => 0.0)
  end

  def self.down
  end
end
