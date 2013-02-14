require 'spec_helper'

module Spree
  describe StockLocation do
    let(:order) { create(:order_with_line_items, line_items_count: 5) }
    subject { create(:stock_location) }

    it 'builds a default package of all the items' do
      order.reload #temp fix for bug where line_items weren't loaded
      package = subject.default_package(order)
      package.contents.size.should eq 5
      package.weight.should > 0
    end

    it 'builds an array of packages' do
      order.reload #temp fix for bug where line_items weren't loaded
      packages = subject.packages(order)
      packages.size.should eq 1
      packages.first.contents.size.should eq 5
    end
  end
end
