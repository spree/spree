require 'spec_helper'

module Spree
  module Stock
    describe Package, type: :model do
      subject { Package.new(stock_location) }

      let(:variant) { create(:variant, weight: 25.0) }
      let(:stock_location) { build(:stock_location) }
      let(:order) { create(:order) }

      def build_inventory_unit
        build(:inventory_unit, variant: variant, order: order)
      end

      # The regression this guards: during checkout a fulfillment belongs to a
      # Cart while its units carried an order_id from elsewhere (a cart id
      # dereferenced as an order id). Walking unit → order handed the carrier
      # provider a stranger's ship address; the fulfillment's own owner is the
      # authoritative link.
      describe '#owner' do
        it 'prefers the owner the fulfillment supplied' do
          cart = create(:cart, store: @default_store, ship_address: create(:address))
          fulfillment = create(:shipment, cart: cart, order: nil, stock_location: create(:stock_location))

          package = fulfillment.to_package

          expect(package.owner).to eq(cart)
        end

        it 'never returns a stranger order reachable through a unit' do
          stranger = create(:order)
          cart = create(:cart, store: @default_store)
          fulfillment = create(:shipment, cart: cart, order: nil, stock_location: create(:stock_location))
          fulfillment.fulfillment_items.update_all(order_id: stranger.id)

          expect(fulfillment.to_package.owner).to eq(cart)
        end

        # The same failure shape as the provider bug: weight, dimensions and
        # currency read the owner's store, and a cart-owned package must not
        # lose them just because no order exists yet.
        it 'applies the store tare to a cart-owned package' do
          create(:package_type, store: @default_store, default: true, weight: 2.5, weight_unit: 'lb')
          cart = create(:cart, store: @default_store)
          create(:line_item, cart: cart, order: nil, variant: variant)
          fulfillment = create(:shipment, cart: cart, order: nil, stock_location: create(:stock_location))

          expect(fulfillment.to_package.weight).to eq(27.5)
        end

        it 'falls back to the units for a package with no fulfillment' do
          package = Package.new(stock_location)
          package.add build_inventory_unit

          expect(package.owner).to eq(order)
        end
      end

      it 'calculates the weight of all the contents' do
        4.times { subject.add build_inventory_unit }
        expect(subject.weight).to eq(100.0)
      end

      # The tare applies at this single seam so every weight consumer —
      # calculators, rate providers, weight rules, the weight splitter —
      # inherits it without knowing the preference exists.
      it 'adds the default package type weight on top of the contents' do
        create(:package_type, store: order.store, default: true, weight: 2.5, weight_unit: 'lb')

        4.times { subject.add build_inventory_unit }

        expect(subject.weight).to eq(102.5)
      end

      # The summary is memoized because quoting reads it repeatedly, so a
      # package added to after its first read would otherwise report the
      # volume it had before — and pick the freight tier to match.
      it 'reports the volume it holds now, not the volume it was first asked about' do
        subject.add build_inventory_unit
        first = subject.freight_summary.total_units

        subject.add build_inventory_unit

        expect(subject.freight_summary.total_units).to eq(first + 1)
      end

      it 'forgets a removed item too' do
        item = build_inventory_unit
        subject.add item
        subject.add build_inventory_unit
        subject.freight_summary

        subject.remove(item)

        expect(subject.freight_summary.total_units).to eq(1)
      end

      it 'applies the tare once per package, not per item' do
        create(:package_type, store: order.store, default: true, weight: 2.5, weight_unit: 'lb')

        subject.add build_inventory_unit

        expect(subject.weight).to eq(27.5)
      end

      # A merchant may record a carton in centimetres while the store quotes
      # in pounds and inches. Handing the raw numbers to a carrier reads
      # centimetres as inches — a 2.54x overstatement on every axis.
      describe 'packages measured in another unit than the store uses' do
        it 'converts the tare into the store weight unit' do
          stub_store_preferences(order.store, weight_unit: 'lb')
          create(:package_type, store: order.store, default: true, weight: 1, weight_unit: 'kg')

          subject.add build_inventory_unit

          # 1 kg is about 2.2 lb, not 1.
          expect(subject.weight - 25).to be_within(0.01).of(2.2046)
        end

        it 'converts the box dimensions into the store dimension unit' do
          stub_store_preferences(order.store, unit_system: 'imperial')
          create(:package_type, store: order.store, default: true,
                                length: 25.4, width: 50.8, height: 76.2, dimensions_unit: 'cm')

          subject.add build_inventory_unit

          expect(subject.dimensions).to eq(length: 10.0, width: 20.0, height: 30.0)
        end
      end

      describe '#dimensions' do
        it 'is nil until the store has a fully measured default package' do
          subject.add build_inventory_unit
          expect(subject.dimensions).to be_nil

          create(:package_type, store: order.store, default: true, length: 12, width: 9, height: nil, dimensions_unit: 'in')
          expect(subject.dimensions).to be_nil
        end

        it 'returns the configured box verbatim, never derived from items' do
          create(:package_type, store: order.store, default: true, length: 12, width: 9, height: 4, dimensions_unit: 'in')

          subject.add build_inventory_unit

          expect(subject.dimensions).to eq(length: 12.0, width: 9.0, height: 4.0)
        end
      end

      context 'currency' do
        let(:unit) { build_inventory_unit }

        before { subject.add unit }

        it 'returns the currency based on the currency from the order' do
          expect(subject.currency).to eql 'USD'
        end
      end

      it 'filters by on_hand and backordered' do
        4.times { subject.add build_inventory_unit }
        3.times { subject.add build_inventory_unit, :backordered }
        expect(subject.on_hand.count).to eq 4
        expect(subject.backordered.count).to eq 3
      end

      it 'calculates the quantity by state' do
        4.times { subject.add build_inventory_unit }
        3.times { subject.add build_inventory_unit, :backordered }

        expect(subject.quantity).to eq 7
        expect(subject.quantity(:on_hand)).to eq 4
        expect(subject.quantity(:backordered)).to eq 3
      end

      it 'returns nil for content item not found' do
        unit = build_inventory_unit
        item = subject.find_item(unit, :on_hand)
        expect(item).to be_nil
      end

      it 'finds content item for an inventory unit' do
        unit = build_inventory_unit
        subject.add unit
        item = subject.find_item(unit, :on_hand)
        expect(item.quantity).to eq 1
      end

      # Candidate methods are exactly the package's delivery profile's —
      # the profile splitter guarantees homogeneous packages.
      describe '#eligible_delivery_methods' do
        let!(:shipping_dm) { create(:delivery_method) }
        let!(:digital_dm) { create(:digital_delivery_method) }

        it 'returns the methods of the items resolved profile' do
          variant1 = create(:product).default_variant
          variant2 = create(:product).default_variant
          contents = [ContentItem.new(build(:inventory_unit, variant_id: variant1.id)),
                      ContentItem.new(build(:inventory_unit, variant_id: variant2.id))]

          package = Package.new(stock_location, contents)
          expect(package.eligible_delivery_methods).to eq([shipping_dm])
        end

        it 'returns the digital profile methods for a digital package' do
          digital = create(:digital_product).default_variant
          contents = [ContentItem.new(build(:inventory_unit, variant_id: digital.id))]

          package = Package.new(stock_location, contents)
          expect(package.eligible_delivery_methods).to eq([digital_dm])
        end

        # Per-product exclusions moved to DeliveryMethodRules::ExcludedProductsRule,
        # covered in delivery_method_rule_spec.rb.
      end

      it 'can convert to a fulfillment' do
        2.times { subject.add build_inventory_unit }
        subject.add build_inventory_unit, :backordered

        delivery_method = build(:delivery_method)
        subject.delivery_rates = [Spree::DeliveryRate.new(delivery_method: delivery_method, cost: 10.00, selected: true)]

        fulfillment = subject.to_fulfillment
        expect(fulfillment.stock_location).to eq subject.stock_location
        expect(fulfillment.fulfillment_items.size).to eq 3

        first_unit = fulfillment.fulfillment_items.first
        expect(first_unit.variant).to eq variant
        expect(first_unit.state).to eq 'on_hand'
        expect(first_unit).to be_pending

        last_unit = fulfillment.fulfillment_items.last
        expect(last_unit.variant).to eq variant
        expect(last_unit.state).to eq 'backordered'

        expect(fulfillment.delivery_method).to eq delivery_method
      end

      describe '#add_multiple' do
        it 'adds multiple inventory units' do
          expect { subject.add_multiple [build_inventory_unit, build_inventory_unit] }.to change(subject, :quantity).by(2)
        end

        it 'allows adding with a state' do
          expect { subject.add_multiple [build_inventory_unit, build_inventory_unit], :backordered }.to change { subject.backordered.count }.by(2)
        end

        it 'defaults to adding with the on hand state' do
          expect { subject.add_multiple [build_inventory_unit, build_inventory_unit] }.to change { subject.on_hand.count }.by(2)
        end
      end

      describe '#remove' do
        let(:unit) { build_inventory_unit }

        context 'there is a content item for the inventory unit' do
          before { subject.add unit }

          it 'removes that content item' do
            expect { subject.remove(unit) }.to change(subject, :quantity).by(-1)
            expect(subject.contents.map(&:inventory_unit)).not_to include unit
          end
        end

        context 'there is no content item for the inventory unit' do
          it "doesn't change the set of content items" do
            expect { subject.remove(unit) }.not_to change(subject, :quantity)
          end
        end
      end

      describe '#order' do
        let(:unit) { build_inventory_unit }

        context 'there is an inventory unit' do
          before { subject.add unit }

          it 'returns an order' do
            expect(subject.order).to be_a_kind_of Spree::Order
            expect(subject.order).to eq unit.order
          end
        end

        context 'there is no inventory unit' do
          it 'returns nil' do
            expect(subject.order).to eq nil
          end
        end
      end

      context '#volume' do
        # Cubic meters, not the product of raw dimension columns: the same
        # numbers read as inches rather than centimeters are a sixteenfold
        # error, which is why freight math never multiplies columns directly.
        it 'reports the packed volume in cubic meters' do
          variant = build(:variant, width: 10, height: 20, depth: 30, dimensions_unit: 'cm')
          contents = [ContentItem.new(build(:inventory_unit, variant: variant, quantity: 2))]
          package = Package.new(stock_location, contents)

          expect(package.volume).to eq(BigDecimal('0.012'))
        end

        it 'reads the same box in inches as a larger volume' do
          metric = build(:variant, width: 10, height: 20, depth: 30, dimensions_unit: 'cm')
          imperial = build(:variant, width: 10, height: 20, depth: 30, dimensions_unit: 'in')

          metric_package = Package.new(stock_location, [ContentItem.new(build(:inventory_unit, variant: metric))])
          imperial_package = Package.new(stock_location, [ContentItem.new(build(:inventory_unit, variant: imperial))])

          expect(imperial_package.volume).to be > metric_package.volume
        end
      end

      context '#dimension' do
        it 'calculates the sum of the dimension of all the items' do
          contents = [ContentItem.new(build(:inventory_unit, variant: build(:variant))),
                      ContentItem.new(build(:inventory_unit, variant: build(:variant))),
                      ContentItem.new(build(:inventory_unit, variant: build(:variant))),
                      ContentItem.new(build(:inventory_unit, variant: build(:variant)))]
          package = Package.new(stock_location, contents)
          expect(package.dimension).to eq contents.sum(&:dimension)
        end
      end
    end
  end
end
