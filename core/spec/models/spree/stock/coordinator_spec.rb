require 'spec_helper'

module Spree
  module Stock
    describe Coordinator do
      let(:order) { create(:order_with_line_items, line_items_count: 5) }
      let!(:stock_location) { create(:stock_location) }

      before :all do
        Spree::Stock.default_splitters = [
         Spree::Stock::Splitter::Backordered,
         Spree::Stock::Splitter::ShippingCategory
        ]
      end

      it 'builds a list of packages for an order' do
        packages = subject.packages order
        puts packages.inspect
      end
    end
  end
end
