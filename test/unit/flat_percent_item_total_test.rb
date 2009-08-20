require 'test_helper'

class FlatPercentItemTotalTest < ActiveSupport::TestCase
  context "Calculator::FlatPercentItemTotal" do
    [Coupon, ShippingMethod].each do |calculable| 
      should "be available to #{calculable.to_s}" do
       assert calculable.calculators.include?(Calculator::FlatPercentItemTotal)
      end
    end
    should "not be available to TaxRate" do
      assert !TaxRate.calculators.include?(Calculator::FlatPercentItemTotal)
    end
  end
end