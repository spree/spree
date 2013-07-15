require 'spec_helper'

module Spree
  module Stock
    describe RemainingPacker do
      let(:order) { mock_model(Order) }
      let(:stock_location) { mock_model(StockLocation) }
      let(:order_counter) { double(OrderCounter, :remaining => 4) }

      subject { RemainingPacker.new(stock_location, order, order_counter) }

      it 'default_package is single package with all remaining items' do
        variant = mock_model(Variant)
        order_counter.should_receive(:variants_with_remaining).and_return([variant])
        subject.should_receive(:stock_status).with(variant, 4).and_return([2,2])
        package = subject.default_package

        package.on_hand.first.quantity.should eq 2
        package.backordered.first.quantity.should eq 2
      end
    end
  end
end
