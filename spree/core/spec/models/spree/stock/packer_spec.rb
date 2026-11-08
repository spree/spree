require 'spec_helper'

module Spree
  module Stock
    describe Packer, type: :model do
      subject { Packer.new(stock_location, inventory_units) }

      let(:inventory_units) { [FulfillmentItem.new(variant: create(:variant))] }
      let(:stock_location) { create(:stock_location) }

      context 'packages' do
        it 'builds an array of packages' do
          packages = subject.packages
          expect(packages).to be_a Array
          expect(packages.first).to be_a Package
        end

        it 'allows users to set splitters to an empty array' do
          packer = Packer.new(StockLocation.new, [], [])
          expect(packer).not_to receive(:build_splitter)
          packer.packages
        end
      end

      context 'default_package' do
        let!(:inventory_units) { Array.new(2) { FulfillmentItem.new variant: create(:variant) } }

        it 'preloads reservations when a custom routing packer has no level cache' do
          stub_store_preferences(stock_reservations_enabled: true)
          owner = create(:cart, store: stock_location.store)
          inventory_units.each { |unit| stock_location.stock_level_or_create(unit.variant).set_count_on_hand(10) }
          expect(Spree::StorePreferences.read(stock_location.store, :stock_reservations_enabled)).to be(true)
          queries = 0
          subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
            queries += 1 if !payload[:cached] && payload[:name].to_s.include?('StockReservation')
          end

          package = Packer.new(stock_location, inventory_units, owner: owner).default_package

          expect(package.quantity).to eq(2)
          expect(queries).to be <= 1
        ensure
          ActiveSupport::Notifications.unsubscribe(subscription) if subscription
        end

        it 'does not load unused reservations when a packer has no purchase owner' do
          inventory_units.each { |unit| stock_location.stock_level_or_create(unit.variant).set_count_on_hand(10) }
          queries = 0
          subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
            queries += 1 if !payload[:cached] && payload[:name].to_s.include?('StockReservation')
          end

          package = subject.default_package

          expect(package.quantity).to eq(2)
          expect(queries).to eq(0)
        ensure
          ActiveSupport::Notifications.unsubscribe(subscription) if subscription
        end

        it 'contains all the items' do
          inventory_units.each do |inventory_unit|
            stock_location.propagate_variant(inventory_unit.variant)
          end
          package = subject.default_package
          expect(package.contents.size).to eq 2
        end

        it 'variants are added as backordered without enough on_hand' do
          inventory_units.each do |inventory_unit|
            stock_location.propagate_variant(inventory_unit.variant)
          end
          expect(stock_location).to receive(:fill_status).twice.and_return(
            *(Array.new(1, [1, 0]) + Array.new(1, [0, 1]))
          )

          package = subject.default_package
          expect(package.on_hand.size).to eq 1
          expect(package.backordered.size).to eq 1
        end

        context 'two lines of one variant' do
          let(:variant) { create(:variant) }
          let(:inventory_units) { Array.new(2) { FulfillmentItem.new(variant: variant, quantity: 3) } }

          it 'splits the shelf between them rather than offering it to each in full' do
            stock_location.stock_level_or_create(variant).update!(count_on_hand: 4, backorderable: false)

            package = subject.default_package

            expect(package.on_hand.map(&:quantity)).to eq [3, 1]
            expect(package.backordered).to be_empty
          end
        end

        context "location doesn't have order items in stock" do
          let(:stock_location) { create(:stock_location, propagate_all_variants: false) }
          let(:inventory_units) { [FulfillmentItem.new(variant: create(:variant))] }
          let(:packer) { Packer.new(stock_location, inventory_units) }

          it 'builds an empty package' do
            expect(packer.default_package.contents).to be_empty
          end
        end

        context "doesn't track inventory levels" do
          let(:inventory_units) { Array.new(2) { FulfillmentItem.new(variant: create(:variant)) } }

          before { stub_store_preferences(track_inventory_levels: false) }

          it "doesn't bother stock items status in stock location" do
            expect(subject.stock_location).not_to receive(:fill_status)
            subject.default_package
          end

          it 'still creates package with proper quantity' do
            expect(subject.default_package.quantity).to eq 2
          end
        end
      end
    end
  end
end
