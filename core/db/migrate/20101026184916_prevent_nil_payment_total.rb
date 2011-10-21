class PreventNilPaymentTotal < ActiveRecord::Migration
  def self.up
    execute("UPDATE orders SET payment_total = 0.0 WHERE payment_total IS NULL")
  end

  def self.down
  end
end
