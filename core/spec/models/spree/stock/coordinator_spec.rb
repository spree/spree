require 'spec_helper'

module Spree
  module Stock
    describe Coordinator do
      let!(:order) { create(:order_with_line_items) }

      subject { Coordinator.new(order) }

      context "packages" do
        it "builds, prioritizes and estimates" do
          subject.should_receive(:build_packages).ordered
          subject.should_receive(:prioritize_packages).ordered
          subject.should_receive(:estimate_packages).ordered
          subject.packages
        end
      end

      describe "#shipments" do
        let(:packages) { [build(:stock_package_fulfilled), build(:stock_package_fulfilled)] }

        before { subject.stub(:packages).and_return(packages) }

        it "turns packages into shipments" do
          shipments = subject.shipments
          expect(shipments.count).to eq packages.count
          shipments.each { |shipment| expect(shipment).to be_a Shipment }
        end

        it "puts the order's ship address on the shipments" do
          shipments = subject.shipments
          shipments.each { |shipment| expect(shipment.address).to eq order.ship_address }
        end
      end

      context "build packages" do
        it "builds a package for every stock location" do
          subject.packages.count == StockLocation.count
        end

        context "missing stock items in stock location" do
          let!(:another_location) { create(:stock_location, propagate_all_variants: false) }

          it "builds packages only for valid stock locations" do
            subject.build_packages.count.should == (StockLocation.count - 1)
          end
        end
      end
    end
  end
end
