require 'spec_helper'

module Spree
  module Stock
    describe Coordinator, type: :model do
      subject { Coordinator.new(order) }

      let(:order) { create(:order_with_line_items) }

      context 'packages' do
        it 'builds, prioritizes and estimates' do
          expect(subject).to receive(:build_packages).ordered
          expect(subject).to receive(:prioritize_packages).ordered
          expect(subject).to receive(:estimate_packages).ordered
          subject.packages
        end
      end

      describe '#shipments' do
        let(:packages) { [build(:stock_package_fulfilled), build(:stock_package_fulfilled)] }

        before { allow(subject).to receive(:packages).and_return(packages) }

        it 'turns packages into shipments' do
          shipments = subject.shipments
          expect(shipments.count).to eq packages.count
          expect(shipments).to all(be_a(Shipment))
        end

        it "puts the order's ship address on the shipments" do
          shipments = subject.shipments
          shipments.each { |shipment| expect(shipment.address).to eq order.ship_address }
        end
      end

      context 'build packages' do
        let!(:stock_location1) { create(:stock_location, backorderable_default: false) }
        let!(:stock_location2) { create(:stock_location, backorderable_default: false) }
        let!(:product) { create(:product) }

        let!(:order) do
          product.stock_items.map { |stock_item| stock_item.adjust_count_on_hand(1) }
          line_item = create(:line_item, product: product, quantity: 2)
          line_item.order
        end

        it 'builds a package for every stock location' do
          expect(subject.build_packages.count).to eq(StockLocation.count)
        end

        context 'missing stock items in stock location' do
          let!(:another_location) { create(:stock_location, propagate_all_variants: false) }

          it 'builds packages only for valid stock locations' do
            expect(subject.build_packages.count).to eq(StockLocation.count - 1)
          end
        end
      end
    end
  end
end
