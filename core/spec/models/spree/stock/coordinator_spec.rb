require 'spec_helper'

module Spree
  module Stock
    describe Coordinator do
      let(:package) { build(:stock_package_fulfilled) }
      let(:order) { package.order }
      let(:stock_location) { package.stock_location }

      before :all do
        Spree::Stock.default_splitters = [
         Spree::Stock::Splitter::Backordered,
         Spree::Stock::Splitter::ShippingCategory
        ]
      end

      it 'builds a list of packages for an order' do
        StockLocation.should_receive(:all).and_return([stock_location])
        subject.should_receive(:build_packer).and_return(double(:packages => [package]))

        packages = subject.packages order
        packages.count.should == 1
      end

      it 'deduplicates packages when two locations can fulfill' do
        StockLocation.should_receive(:all).and_return([stock_location])
        subject.should_receive(:build_packer).and_return(double(:packages => [package]))

        packages = subject.packages order
        packages.count.should == 1
      end
    end
  end
end
