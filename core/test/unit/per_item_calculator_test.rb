require 'test_helper'

class PerItemCalculatorTest < ActiveSupport::TestCase
  context "Calculator::PerItem" do
    [Promotion, ShippingMethod].each do |calculable| 
      should "be available to #{calculable.to_s}" do
       assert calculable.calculators.include?(Calculator::PerItem)
      end
    end
    should "not be available to TaxRate" do
      assert !TaxRate.calculators.include?(Calculator::PerItem)
    end
  end
end
