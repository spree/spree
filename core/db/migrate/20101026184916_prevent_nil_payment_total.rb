class PreventNilPaymentTotal < ActiveRecord::Migration
  def self.up
    execute("update orders set payment_total = 0.0 where payment_total is null")
  end

  def self.down
  end
end
