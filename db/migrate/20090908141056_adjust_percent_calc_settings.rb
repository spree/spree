class AdjustPercentCalcSettings < ActiveRecord::Migration
  def self.up
    Calculator::FlatPercentItemTotal.all.each {|c| c.preferred_flat_percent *= 100.0; c.save }
  end

  def self.down
    Calculator::FlatPercentItemTotal.all.each {|c| c.preferred_flat_percent /= 100.0; c.save }
  end
end
