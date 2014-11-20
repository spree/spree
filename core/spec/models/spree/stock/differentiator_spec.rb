require 'spec_helper'

module Spree
  module Stock
    describe Differentiator, :type => :model do
      let(:variant1) { mock_model(Variant) }
      let(:variant2) { mock_model(Variant) }

      let(:stock_location) { mock_model(StockLocation) }

      let(:line_items) do
        [mock_model(LineItem, variant: variant1, quantity: 2),
         mock_model(LineItem, variant: variant2, quantity: 2)]
      end

      let(:order) { mock_model(Order, line_items: line_items) }

      let(:package1) do
        Package.new(stock_location, order).tap { |p| p.add(line_items.first, 1) }
      end

      let(:package2) do
        Package.new(stock_location, order).tap { |p| p.add(line_items.last, 1) }
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
