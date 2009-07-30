require 'test_helper'

class FlatPercentCalculatorTest < ActiveSupport::TestCase
  context "Calculator::FlatPercent" do
    [Coupon, ShippingMethod].each do |calculable| 
      should "be available to #{calculable.to_s}" do
       assert calculable.calculators.include?(Calculator::FlatPercent)
      end
    end
    should "not be available to TaxRate" do
      assert !TaxRate.calculators.include?(Calculator::FlatPercent)
    end
  end
end