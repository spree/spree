class UpdateLegacyCalculators < ActiveRecord::Migration
  def self.up
    execute "UPDATE calculators SET type = 'Calculator::FlatRate' WHERE type = 'FlatRateShippingCalculator'"
    execute "UPDATE calculators SET type = 'Calculator::FlatRate' WHERE type = 'FlatRateCouponCalculator'"    
  end

  def self.down
  end
end
