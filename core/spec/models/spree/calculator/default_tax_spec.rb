require 'spec_helper'

describe Spree::Calculator::DefaultTax do
  let!(:tax_category) { create(:tax_category, :tax_rates => []) }
  let!(:rate) { mock_model(Spree::TaxRate, :tax_category => tax_category, :amount => 0.05, :included_in_price => vat) }
  let(:vat) { false }
  let!(:calculator) { Spree::Calculator::DefaultTax.new(:calculable => rate ) }
  let!(:order) { create(:order) }
  let!(:line_item_1) { create(:line_item, :price => 10, :quantity => 3, :tax_category => tax_category) }
  let!(:line_item_2) { create(:line_item, :price => 5, :quantity => 1, :tax_category => tax_category) }

  context "#compute" do
    context "when given an order" do
      before do
        order.stub :line_items => [line_item_1, line_item_2]
      end

      context "when no line items match the tax category" do
        before do
          line_item_1.tax_category = nil
          line_item_2.tax_category = nil
        end

        it "should be 0" do
          calculator.compute(order).should == 0
        end
      end

      context "when one item matches the tax category" do
        before do
          line_item_1.tax_category = tax_category
          line_item_2.tax_category = nil
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

    context "when tax is included in price" do
      let(:vat) { true }
      context "when the variant matches the tax category" do
        it "should be equal to the item total * rate" do
          calculator.compute(line_item_1).should == 1.43
        end
      end
    end

    context "when tax is not included in price" do
      context "when the variant matches the tax category" do
        it "should be equal to the item total * rate" do
          calculator.compute(line_item_1).should == 1.50
        end
      end
    end

    context "when given a line item" do

      context "when the variant does not match the tax category" do
        before do
          line_item_2.tax_category = nil
        end

        it "should be 0" do
          calculator.compute(line_item_2).should == 0
        end
      end
    end
  end
end
