require 'test_helper'
class SalesTaxCalculatorTest < ActiveSupport::TestCase
  context "Calculator::SalesTax" do 
    should "be available to TaxRate" do
      assert TaxRate.calculators.include?(Calculator::SalesTax)
    end
    should "not be available to ShippingMethod" do
      assert !Promotion.calculators.include?(Calculator::SalesTax)
    end
    should "not be available to Promotion" do
      assert !ShippingMethod.calculators.include?(Calculator::SalesTax)
    end

    context "compute" do
      setup do
        @order = Factory(:order)
        @tax_category = TaxCategory.create(:name => "foo") 
        @taxable = Factory(:product, :tax_category => @tax_category)
        @non_taxable = Factory(:product, :tax_category => nil)
      end

      context "for order where no line item contains a taxable product" do                                                                 
        setup do 
          @order.line_items = [Factory(:line_item, :variant => Factory(:variant, :product => @non_taxable))]
          @calculator = Calculator::SalesTax.new(:calculable => Factory(:tax_rate))
        end
        should "return zero if none of the line items contains a taxable product" do
          assert_equal 0, @calculator.compute(@order)
        end
      end       

      context "for order with some taxable items" do
        setup do             
          @order.line_items = [Factory(:line_item, :variant => Factory(:variant, :product => @taxable), :price => 10, :quantity => 10), 
                               Factory(:line_item, :variant => Factory(:variant, :product => @non_taxable))] 
          @calculator = Calculator::SalesTax.new(:calculable => TaxRate.new(:amount => 0.05, :tax_category => @tax_category))
        end
        should "tax only the taxable line items" do
          assert_equal 5, @calculator.compute(@order)
        end
      end

    end

  end
end
