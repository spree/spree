class Order < ActiveRecord::Base; end;

class PreventNilPaymentTotal < ActiveRecord::Migration
  def up
    Order.where(:payment_total => nil).update_all(:payment_total => 0.0)
  end

  def down
  end
end
