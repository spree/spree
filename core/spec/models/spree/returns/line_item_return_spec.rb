require 'spec_helper'

module Spree
  module Returns
    describe LineItemReturn do
      let(:order)     { Order.new }
      let(:line_item) { LineItem.new(price: 100.0, quantity: 2) }
      let(:quantity)  { 1 }

      before { order.line_items << line_item }
      subject { LineItemReturn.new(line_item, quantity) }

      describe "#initialize" do
        it "requires a valid line_item" do
          expect { LineItemReturn.new(Object.new, 1) }.to raise_error "Line Item Required"
          expect { LineItemReturn.new(build(:line_item), 1) }.not_to raise_error
        end

        it "requires a valid quantity" do
          expect { LineItemReturn.new(build(:line_item), "foo") }.to raise_error "Quantity Required"
          expect { LineItemReturn.new(build(:line_item), 1) }.not_to raise_error
        end
      end

      describe "#amount_to_return" do

        context "no promotions or taxes" do
          its(:amount_to_return) { should eq line_item.price }
        end

        context "line item promotions" do
          before { line_item.promo_total = -20.0 }
          its(:amount_to_return) { should eq line_item.price - 10 }
        end

        context "included taxes" do
          before { line_item.included_tax_total = 20.0 }
          # TODO i dont think this is right, but don't have a full understanding of included vs additional tax
          its(:amount_to_return) { should eq line_item.price }
        end

        context "additional taxes" do
          before { line_item.additional_tax_total = 20.0 }
          # TODO i dont think this is right, but don't have a full understanding of included vs additional tax
          its(:amount_to_return) { should eq line_item.price + 10 }
        end

        context "order adjustments" do
          before do
            order.adjustment_total = -30
            order.line_items << LineItem.new(price: 100.0, quantity: 1)
          end
          its(:amount_to_return) { should eq line_item.price - 10 }
        end

        context "shipping adjustments" do
          before { order.shipments << Shipment.new(adjustment_total: -50) }
          its(:amount_to_return) { should eq line_item.price }
        end
      end
    end
  end
end
