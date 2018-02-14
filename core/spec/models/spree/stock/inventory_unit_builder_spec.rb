require 'spec_helper'

module Spree
  module Stock
    describe InventoryUnitBuilder, type: :model do
      subject { InventoryUnitBuilder.new(order) }

      let(:line_item_1) { build(:line_item) }
      let(:line_item_2) { build(:line_item, quantity: 2) }
      let(:order) { build(:order, line_items: [line_item_1, line_item_2]) }

      describe '#units' do
        it "returns an inventory unit for each quantity for the order's line items" do
          units = subject.units
          expect(units.count).to eq 2
          expect(units.first.line_item).to eq line_item_1
          expect(units.first.variant).to eq line_item_1.variant
          expect(units.first.quantity).to eq line_item_1.quantity

          expect(units.second.line_item).to eq line_item_2
          expect(units.second.variant).to eq line_item_2.variant
          expect(units.second.quantity).to eq line_item_2.quantity
        end

        it 'builds the inventory units as pending' do
          expect(subject.units.map(&:pending).uniq).to eq [true]
        end

        it 'sets the order_id on inventory units' do
          expect(subject.units.map(&:order_id).uniq).to eq [order.id]
        end
      end
    end
  end
end
