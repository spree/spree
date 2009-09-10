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

    context "compute" do
      setup do
        @order = Factory(:order)
        @order.item_total = 123
        @calculator = Calculator::FlatPercentItemTotal.new(:preferred_flat_percent => 10)
      end

      context "apply the percentage rate" do
        should "compute ten percent" do
          assert_equal((123 * 10 / 100.0), @calculator.compute(@order))
        end
      end       
    end
  end
end
