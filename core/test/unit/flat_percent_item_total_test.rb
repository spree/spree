require 'test_helper'

class FlatPercentItemTotalTest < ActiveSupport::TestCase
  context "Calculator::FlatPercentItemTotal" do
    [Promotion, ShippingMethod].each do |calculable| 
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
        @order.line_items << Factory(:line_item, :price => 50, :quantity => 2)
        @order.line_items << Factory(:line_item, :price => 23, :quantity => 1)
        @calculator = Calculator::FlatPercentItemTotal.new(:preferred_flat_percent => 10)
      end

      context "apply the percentage rate" do
        should "compute ten percent" do
          assert_equal((123 * 10 / 100.0), @calculator.compute(@order.line_items))
        end
      end       
    end
  end
end
