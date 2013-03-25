require 'spec_helper'

module Spree
  module Stock
    describe Packer do
      let(:order) { create(:order_with_line_items, line_items_count: 5) }
      let(:stock_location) { mock_model(StockLocation, fill_status: [20, 0]) }

      subject { Packer.new(stock_location, order) }

      context 'packages' do
        it 'builds an array of packages' do
          packages = subject.packages
          packages.size.should eq 1
          packages.first.contents.size.should eq 5
        end
      end

      context 'default_package' do
        it 'contains all the items' do
          package = subject.default_package
          package.contents.size.should eq 5
          package.weight.should > 0
        end

        it 'variants are added as backordered without enough on_hand' do
          stock_location.should_receive(:fill_status).exactly(5).times.and_return([2,3])
          package = subject.default_package
          package.on_hand.size.should eq 5
          package.backordered.size.should eq 5
        end
      end
    end
  end
end
