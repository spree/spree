require 'spec_helper'

module Spree
  module Stock
    describe Coordinator, type: :model do
      subject { Coordinator.new(order) }

      let(:store) { @default_store }
      let(:order) { create(:order_with_line_items, store: store) }

      context 'packages' do
        it 'builds, prioritizes and estimates' do
          expect(subject).to receive(:build_packages).ordered
          expect(subject).to receive(:prioritize_packages).ordered
          expect(subject).to receive(:estimate_packages).ordered
          subject.packages
        end
      end

      # A proposed package's inventory units belong to no order yet, so the
      # walk-to-an-order fallback answers nil and everything reading the buyer
      # through the package — the packaging tare, the channel and company
      # eligibility rules — silently sees nothing.
      describe 'the package owner' do
        it 'carries the purchase being quoted onto every package' do
          expect(subject.build_packages.map(&:owner)).to all(eq(order))
        end

        it 'carries a cart the same way, before any order exists' do
          cart = create(:cart, store: store)
          create(:line_item, cart: cart, order: nil)

          owners = Coordinator.new(cart.reload).build_packages.map(&:owner)

          expect(owners).to all(eq(cart))
        end
      end

      # Allocation asks each profile (and the order's channel) about every
      # candidate location, so membership must be read from loaded rows —
      # re-querying per question multiplied with items × locations.
      describe 'query cost' do
        it 'does not re-query origin-group membership per unit and location' do
          4.times do |index|
            create(:stock_location, store: store, name: "Warehouse #{index} #{SecureRandom.hex(3)}",
                                    propagate_all_variants: true, backorderable_default: true)
          end
          big_order = create(:order_with_line_items, store: store, line_items_count: 4)

          membership_queries = 0
          subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
            next if payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)

            membership_queries += 1 if payload[:sql].include?('spree_delivery_origin_group_locations')
          end

          Coordinator.new(big_order.reload).packages
          ActiveSupport::Notifications.unsubscribe(subscription)

          # One read per profile is fine; per unit per location is the bug.
          expect(membership_queries).to be < 10
        end
      end

      # Origin groups exist so different warehouses can serve different zones.
      # The destination has to decide which warehouse packs the goods, or the
      # cart allocates to one whose group has no method for the address and
      # drops the item as undeliverable while the other could have shipped it.
      describe 'multi-origin allocation' do
        let(:profile) { store.default_delivery_profile }
        let!(:us_warehouse) do
          create(:stock_location, store: store, name: "US #{SecureRandom.hex(3)}",
                                  propagate_all_variants: true, default: true)
        end
        let!(:eu_warehouse) do
          create(:stock_location, store: store, name: "EU #{SecureRandom.hex(3)}",
                                  propagate_all_variants: true, country: Spree::Country.by_iso('NL'))
        end

        let(:us_group) { profile.default_origin_group }
        let(:eu_group) { profile.delivery_origin_groups.create!(name: 'EU Fulfillment') }

        let(:netherlands) { Spree::Country.by_iso('NL') }
        let(:dutch_address) { create(:address, country: netherlands, state: nil) }
        let(:order) { create(:order_with_line_items, store: store, ship_address: dutch_address) }

        before do
          # Every method in this setup is zone-bound, as it is for a merchant
          # who split their origins by region — the factory's worldwide method
          # would make the US warehouse look able to deliver anywhere.
          order
          Spree::DeliveryMethod.delete_all

          us_group.stock_locations = [us_warehouse]
          eu_group.stock_locations = [eu_warehouse]

          us_zone = create(
            :delivery_zone_with_country,
            store: store, delivery_profile: profile,
            delivery_origin_group: us_group, country: Spree::Country.by_iso('US')
          )
          eu_zone = create(
            :delivery_zone_with_country,
            store: store, delivery_profile: profile,
            delivery_origin_group: eu_group, country: netherlands
          )

          create(
            :delivery_method,
            name: 'US Standard', store: store, delivery_profile: profile,
            delivery_origin_group: us_group, delivery_zone: us_zone
          )
          create(
            :delivery_method,
            name: 'EU Standard', store: store, delivery_profile: profile,
            delivery_origin_group: eu_group, delivery_zone: eu_zone
          )

          order.variants.each do |variant|
            [us_warehouse, eu_warehouse].each do |location|
              location.stock_level_or_create(variant).adjust_count_on_hand(10)
            end
          end
        end

        it 'allocates from the origin whose group serves the destination' do
          packages = subject.packages

          expect(packages.map { |package| package.stock_location.name }).to eq [eu_warehouse.name]
          expect(packages.first.delivery_rates.map(&:name)).to include('EU Standard')
        end
      end

      describe 'channel-scoped allocation' do
        let!(:warehouse) { create(:stock_location, store: store, name: "Warehouse #{SecureRandom.hex(3)}", backorderable_default: true, propagate_all_variants: true) }
        let(:channel) { create(:channel, store: store) }

        it 'never allocates from a location the order channel is not served by' do
          channel.stock_locations = [create(:stock_location, store: store, name: "Other #{SecureRandom.hex(3)}")]
          order.update!(channel: channel)

          packages = subject.packages
          expect(packages.map { |package| package.stock_location.id }).not_to include(warehouse.id)
        end

        it 'allocates normally when the channel has no allowlist' do
          order.update!(channel: channel)

          expect(subject.packages).to be_present
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
          product.stock_levels.map { |stock_level| stock_level.adjust_count_on_hand(1) }
          line_item = create(:line_item, product: product, variant: product.default_variant, quantity: 2)
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
