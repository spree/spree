require 'spec_helper'

module Spree
  module Stock
    describe Differentiator, :type => :model do
      let(:variant1) { mock_model(Variant) }
      let(:variant2) { mock_model(Variant) }

      let(:line_item1) { build(:line_item, variant: variant1, quantity: 2) }
      let(:line_item2) { build(:line_item, variant: variant2, quantity: 2) }

      let(:stock_location) { mock_model(StockLocation) }

      let(:inventory_unit1) { build(:inventory_unit, variant: variant1, line_item: line_item1) }
      let(:inventory_unit2) { build(:inventory_unit, variant: variant2, line_item: line_item2) }

      let(:order) { mock_model(Order, line_items: [line_item1, line_item2]) }

      let(:package1) do
        Package.new(stock_location).tap { |p| p.add(inventory_unit1) }
      end

      let(:package2) do
        Package.new(stock_location).tap { |p| p.add(inventory_unit2) }
      end

      let(:packages) { [package1, package2] }

      subject { Differentiator.new(order, packages) }

      it { is_expected.to be_missing }

      it 'calculates the missing items' do
        expect(subject.missing[variant1]).to eq 1
        expect(subject.missing[variant2]).to eq 1
      end
    end
  end
end
