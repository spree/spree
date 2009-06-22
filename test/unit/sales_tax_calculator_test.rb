require 'test_helper'
class SalesTaxCalculatorTest < ActiveSupport::TestCase
  context "calculate_tax" do
    setup do
      @order = Factory(:order)
      @tax_category = TaxCategory.create(:name => "foo") 
      @taxable = Factory(:product, :tax_category => @tax_category)
      @non_taxable = Factory(:product, :tax_category => nil)
    end
    
    should "return zero if no rates provided" do
      assert_equal 0, Spree::SalesTaxCalculator.calculate_tax(@order, [])
    end
    
    context "for order where no line item contains a taxable product" do                                                                 
      setup { @order.line_items = [Factory(:line_item, :variant => Factory(:variant, :product => @non_taxable))] }
      should "return zero if none of the line items contains a taxable product" do
        assert_equal 0, Spree::SalesTaxCalculator.calculate_tax(@order, [])
      end
    end       
    
    context "for order with some taxable items" do
      setup do             
        @order.line_items = [Factory(:line_item, :variant => Factory(:variant, :product => @taxable), :price => 10, :quantity => 10), 
                             Factory(:line_item, :variant => Factory(:variant, :product => @non_taxable))] 
        @tax_rate = TaxRate.new(:amount => 0.05, :tax_category => @tax_category)
      end
      should "tax only the taxable line items" do
        assert_equal 5, Spree::SalesTaxCalculator.calculate_tax(@order, [@tax_rate])
      end
    end
    
  end
end
