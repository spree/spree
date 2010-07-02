require 'test_helper'
class VatTaxCalculatorTest < ActiveSupport::TestCase
  context "Calculator::Vat" do
    should "be available to TaxRate" do
      assert TaxRate.calculators.include?(Calculator::Vat)
    end
    should "not be available to ShippingMethod" do
      assert !Promotion.calculators.include?(Calculator::Vat)
    end
    should "not be available to Promotion" do
      assert !ShippingMethod.calculators.include?(Calculator::Vat)
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
          @calculator = Calculator::Vat.new(:calculable => Factory(:tax_rate))
        end
        should "return zero if none of the line items contains a taxable product" do
          assert_equal 0, @calculator.compute(@order)
        end
      end

      context "for order with some taxable items" do
        setup do
          @order.line_items = [Factory(:line_item, :variant => Factory(:variant, :product => @taxable), :price => 10, :quantity => 10),
                               Factory(:line_item, :variant => Factory(:variant, :product => @non_taxable))]
          @calculator = Calculator::Vat.new(:calculable => TaxRate.new(:amount => 0.05, :tax_category => @tax_category))
        end
        should "tax only the taxable line items" do
          assert_equal 5, @calculator.compute(@order)
        end
      end
    end

    context "calculate_tax_on" do
      setup do
        country = Factory(:country)
        Spree::Config.set({ :default_country_id => country.id })
        ZoneMember.create(:zoneable => country, :zone => Zone.global)
        tax_category = TaxCategory.create(:name => "foo")
        Calculator::Vat.create!(:calculable => TaxRate.new(:amount => 0.05, :tax_category => tax_category, :zone => Zone.global))
        @taxable = Factory(:product, :tax_category => tax_category)
      end

      should "return non zero amount for a taxable item" do
        assert_not_equal 0, Calculator::Vat.calculate_tax_on(@taxable)
      end
    end
  end

end
