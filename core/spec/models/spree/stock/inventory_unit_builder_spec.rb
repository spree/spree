require 'spec_helper'

module Spree
  module Stock
    describe InventoryUnitBuilder, :type => :model do
      let(:line_item_1) { build(:line_item) }
      let(:line_item_2) { build(:line_item, quantity: 2) }
      let(:order) { build(:order, line_items: [line_item_1, line_item_2]) }

      subject { InventoryUnitBuilder.new(order) }

      describe "#units" do
        it "returns an inventory unit for each quantity for the order's line items" do
          units = subject.units
          expect(units.count).to eq 3
          expect(units.first.line_item).to eq line_item_1
          expect(units.first.variant).to eq line_item_1.variant

          expect(units[1].line_item).to eq line_item_2
          expect(units[1].variant).to eq line_item_2.variant

          expect(units[2].line_item).to eq line_item_2
          expect(units[2].variant).to eq line_item_2.variant
        end

        it "builds the inventory units as pending" do
          expect(subject.units.map(&:pending).uniq).to eq [true]
        end

        it "associates the inventory units to the order" do
          expect(subject.units.map(&:order).uniq).to eq [order]
        end

      end

    end
  end
end
