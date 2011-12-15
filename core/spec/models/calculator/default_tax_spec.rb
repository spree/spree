require 'spec_helper'

describe Spree::Calculator::DefaultTax do
  before do
    #@tax_category = Factory(:tax_category, :tax_rates => [])
    #@rate = mock_model(:tax_rate)
    #@calculator = Spree::Calculator::DefaultTax.new(:calculable => @rate)
  end

  context "#compute" do
    context "when given an order" do
      before { @order = Factory(:order) }

      context "when no line items match the tax category" do
        #before do
          #@order.stub :line_items => [Factory(:line_item), Factory(:line_item)]
        #end

        pending "should be 0" do
          @calculator.compute(@order).should == 0
        end
      end
      context "when one item matches the tax category" do
        pending "should be equal to the item total * rate"
      end
      context "when more than one item matches the tax category" do
        pending "should be equal to the sum of the item totals * rate"
      end
    end
    context "when given a line item" do
      context "when the variant matches the tax category" do
        pending "should be equal to the item total * rate"
      end
      context "when the variant does not match the tax category" do
        pending "should be 0"
      end
    end
  end
end
