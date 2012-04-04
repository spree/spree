require 'spec_helper'

describe Spree::Calculator::DefaultTax do
  let!(:tax_category) { Factory(:tax_category, :tax_rates => []) }
  let!(:rate) { mock_model(Spree::TaxRate, :tax_category => tax_category, :amount => 0.05) }
  let!(:calculator) { Spree::Calculator::DefaultTax.new({:calculable => rate}, :without_protection => true) }
  let!(:order) { Factory(:order) }
  let!(:product_1) { Factory(:product) }
  let!(:product_2) { Factory(:product) }
  let!(:line_item_1) { Factory(:line_item, :product => product_1, :price => 10, :quantity => 3) }
  let!(:line_item_2) { Factory(:line_item, :product => product_2, :price => 5, :quantity => 1) }

  context "#compute" do
    context "when given an order" do
      before do
        order.stub :line_items => [line_item_1, line_item_2]
      end

      context "when no line items match the tax category" do
        before do
          product_1.tax_category = nil
          product_2.tax_category = nil
        end

        it "should be 0" do
          calculator.compute(order).should == 0
        end
      end

      context "when one item matches the tax category" do
        before do
          product_1.tax_category = tax_category
          product_2.tax_category = nil
        end

        it "should be equal to the item total * rate" do
          calculator.compute(order).should == 1.5
        end

        context "correctly rounds to within two decimal places" do
          before do
            line_item_1.price = 10.333
            line_item_1.quantity = 1
          end

          specify do
            # Amount is 0.51665, which will be rounded to...
            calculator.compute(order).should == 0.52
          end

        end
      end


      context "when more than one item matches the tax category" do
        it "should be equal to the sum of the item totals * rate" do
          calculator.compute(order).should == 1.75
        end
      end
    end

    context "when given a line item" do
      context "when the variant matches the tax category" do
        it "should be equal to the item total * rate" do
          calculator.compute(line_item_1).should == 1.43
        end
      end

      context "when the variant does not match the tax category" do
        before do
          line_item_2.product.tax_category = nil
        end

        it "should be 0" do
          calculator.compute(line_item_2).should == 0
        end
      end
    end
  end
end
