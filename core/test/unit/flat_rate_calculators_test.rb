require 'test_helper'
class FlatRateCalculatorTest < ActiveSupport::TestCase
  context "Calculator::FlatRate" do
    [Promotion, ShippingMethod].each do |calculable| 
      should "be available to #{calculable.to_s}" do
       assert calculable.calculators.include?(Calculator::FlatRate)
      end
    end
    should "not be available to TaxRate" do
      assert !TaxRate.calculators.include?(Calculator::FlatRate)
    end
  end
end
