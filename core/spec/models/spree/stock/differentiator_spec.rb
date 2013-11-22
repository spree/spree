require 'spec_helper'

module Spree
  module Stock
    describe Differentiator do
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

      it { should be_missing }

      it 'calculates the missing items' do
        subject.missing[variant1].should eq 1
        subject.missing[variant2].should eq 1
      end
    end
  end
end
