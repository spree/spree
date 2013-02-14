require 'spec_helper'

module Spree
  describe StockLocation do
    let(:order) { create(:order_with_line_items, line_items_count: 5) }
    subject { create(:stock_location) }

    before :all do
      order.reload
      order.line_items.each do |line_item|
        create(:stock_item,
               variant: line_item.variant,
               count_on_hand: 5,
               stock_location: subject)
      end
    end

    context 'default_package' do
      it 'contains all the items' do
        package = subject.default_package(order)
        package.contents.size.should eq 5
        package.weight.should > 0
      end

      it 'variants are added as backordered without enough on_hand' do
        subject.should_receive(:stock_status).exactly(5).times.and_return([2,3])
        package = subject.default_package(order)
        package.on_hand.size.should eq 5
        package.backordered.size.should eq 5
      end
    end

    it 'builds an array of packages' do
      order.reload #temp fix for bug where line_items weren't loaded
      packages = subject.packages(order)
      packages.size.should eq 1
      packages.first.contents.size.should eq 5
    end

    context 'stock_status' do
      before do
        @stock_item = build(:stock_item, count_on_hand: 10)
        subject.should_receive(:stock_item).and_return(@stock_item)
      end

      it 'all on_hand with no backordered' do
        on_hand, backordered = subject.send(:stock_status, double, 5)
        on_hand.should eq 5
        backordered.should eq 0
      end

      it 'some on_hand with some backordered' do
        on_hand, backordered = subject.send(:stock_status, double, 20)
        on_hand.should eq 10
        backordered.should eq 10
      end

      it 'zero on_hand with all backordered' do
        @stock_item.stub(count_on_hand: 0)
        on_hand, backordered = subject.send(:stock_status, double, 20)
        on_hand.should eq 0
        backordered.should eq 20
      end
    end

  end
end
