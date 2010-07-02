require 'test_helper'

class FlexiRateCalculatorTest < ActiveSupport::TestCase
  context "Calculator::FlexiRate" do
    [Promotion, ShippingMethod, ShippingRate].each do |calculable|
      should "be available to #{calculable.to_s}" do
       assert calculable.calculators.include?(Calculator::FlexiRate)
      end
    end
    should "not be available to TaxRate" do
      assert !TaxRate.calculators.include?(Calculator::FlexiRate)
    end

    context "#compute" do
      setup do
        @calculator = Calculator::FlexiRate.new(:preferred_first_item=>10, :preferred_additional_item=>5, :preferred_max_items=>3)
        @order = Factory(:order)
      end

      should "compute 0 if no products" do
        assert_equal(0, @calculator.compute(@order.line_items))
      end

      context "multiple qty=1 products" do
        should "compute correctly for single item" do
          @order.line_items << Factory(:line_item, :price => 1, :quantity => 1)
          assert_equal(10, @calculator.compute(@order.line_items))
        end
        should "compute correctly for 1 additional item" do
          @order.line_items << Factory(:line_item, :price => 1, :quantity => 1)
          @order.line_items << Factory(:line_item, :price => 2, :quantity => 1)
          assert_equal(15, @calculator.compute(@order.line_items))
        end
        should "compute correctly for 2 additional items (full package)" do
          @order.line_items << Factory(:line_item, :price => 1, :quantity => 1)
          @order.line_items << Factory(:line_item, :price => 2, :quantity => 1)
          @order.line_items << Factory(:line_item, :price => 3, :quantity => 1)
          assert_equal(20, @calculator.compute(@order.line_items))
        end
        should "compute correctly for 2 packages (1 full, 1 single item)" do
          @order.line_items << Factory(:line_item, :price => 1, :quantity => 1)
          @order.line_items << Factory(:line_item, :price => 2, :quantity => 1)
          @order.line_items << Factory(:line_item, :price => 3, :quantity => 1)
          @order.line_items << Factory(:line_item, :price => 4, :quantity => 1)
          assert_equal(30, @calculator.compute(@order.line_items))
        end
      end
      context "single product" do
        should "compute correctly for qty=1" do
          @order.line_items << Factory(:line_item, :price => 1, :quantity => 1)
          assert_equal(10, @calculator.compute(@order.line_items))
        end
        should "compute correctly for qty=2 (1 additional)" do
          @order.line_items << Factory(:line_item, :price => 2, :quantity => 2)
          assert_equal(15, @calculator.compute(@order.line_items))
        end
        should "compute correctly for qty=3 (full package)" do
          @order.line_items << Factory(:line_item, :price => 3, :quantity => 3)
          assert_equal(20, @calculator.compute(@order.line_items))
        end
        should "compute correctly for qty=4 (2 packages)" do
          @order.line_items << Factory(:line_item, :price => 4, :quantity => 4)
          assert_equal(30, @calculator.compute(@order.line_items))
        end
      end
      context "mix qty>1 & qty=1 products" do
        should "compute correctly for qty=3 + qty=1 products (2 packages)" do
          @order.line_items << Factory(:line_item, :price => 3, :quantity => 3)
          @order.line_items << Factory(:line_item, :price => 1, :quantity => 1)
          assert_equal(30, @calculator.compute(@order.line_items))
        end
      end
    end
  end
end
