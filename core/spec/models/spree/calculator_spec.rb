require 'spec_helper'

describe Spree::Calculator, :type => :model do

  let(:order) { create(:order) }
  let!(:line_item) { create(:line_item, :order => order) }
  let(:shipment) { create(:shipment, :order => order, :stock_location => create(:stock_location_with_items)) }

  context "with computable" do
    context "and compute methods stubbed out" do
      context "with a Spree::LineItem" do
        it "calls compute_line_item" do
          expect(subject).to receive(:compute_line_item).with(line_item)
          subject.compute(line_item)
        end
      end

      context "with a Spree::Order" do
        it "calls compute_order" do
          expect(subject).to receive(:compute_order).with(order)
          subject.compute(order)
        end
      end

      context "with a Spree::Shipment" do
        it "calls compute_shipment" do
          expect(subject).to receive(:compute_shipment).with(shipment)
          subject.compute(shipment)
        end
      end

      context "with a arbitray object" do
        it "calls the correct compute" do
          s = "Calculator can all"
          expect(subject).to receive(:compute_string).with(s)
          subject.compute(s)
        end
      end
    end

  context "with no stubbing" do
    context "with a Spree::LineItem" do
        it "raises NotImplementedError" do
          expect{subject.compute(line_item)}.to raise_error NotImplementedError, /Please implement \'compute_line_item\(line_item\)\' in your calculator/
        end
      end

      context "with a Spree::Order" do
        it "raises NotImplementedError" do
          expect{subject.compute(order)}.to raise_error NotImplementedError, /Please implement \'compute_order\(order\)\' in your calculator/
        end
      end

      context "with a Spree::Shipment" do
        it "raises NotImplementedError" do
          expect{subject.compute(shipment)}.to raise_error NotImplementedError, /Please implement \'compute_shipment\(shipment\)\' in your calculator/
        end
      end

      context "with a arbitray object" do
        it "raises NotImplementedError" do
          s = "Calculator can all"
          expect{subject.compute(s)}.to raise_error NotImplementedError, /Please implement \'compute_string\(string\)\' in your calculator/
        end
      end
    end
  end

end
