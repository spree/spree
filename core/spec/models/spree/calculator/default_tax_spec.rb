require 'spec_helper'

describe Spree::Calculator::DefaultTax do
  let!(:tax_category) { create(:tax_category, :tax_rates => []) }
  let!(:rate) { mock_model(Spree::TaxRate, :tax_category => tax_category, :amount => 0.05, :included_in_price => vat) }
  let(:vat) { false }
  let!(:calculator) { Spree::Calculator::DefaultTax.new(:calculable => rate ) }
  let!(:order) { create(:order) }
  let!(:line_item) { create(:line_item, :price => 10, :quantity => 3, :tax_category => tax_category) }
  let!(:shipment) { create(:shipment, :cost => 15) }

  context "#compute" do
    context "when tax is included in price" do
      let(:vat) { true }
      context "when the variant matches the tax category" do

        context "when line item is discounted" do
          before { line_item.promo_total = -1 }

          it "should be equal to the item's discounted total * rate" do
            calculator.compute(line_item).should == 1.38
          end
        end

        it "should be equal to the item total * rate" do
          calculator.compute(line_item).should == 1.43
        end
      end
    end

    context "when tax is not included in price" do

      context "when the line item is discounted" do
        before { line_item.promo_total = -1 }

        it "should be equal to the item's discounted total * rate" do
          calculator.compute(line_item).should == 1.45
        end
      end

      context "when the variant matches the tax category" do
        it "should be equal to the item total * rate" do
          calculator.compute(line_item).should == 1.50
        end
      end
    end

    context "when given a line item" do
      context "when the variant does not match the tax category" do
        before do
          line_item.stub :tax_category => nil
        end

        it "should be 0" do
          calculator.compute(line_item).should == 0
        end
      end
    end

    context "when given a shipment" do
      it "should be 5% of 15" do
        calculator.compute(shipment).should == 0.75
      end

      it "takes discounts into consideration" do
        shipment.promo_total = -1
        # 5% of 14
        calculator.compute(shipment).should == 0.7
      end
    end
  end
end
