require 'spec_helper'

module Spree
  module Stock
    describe Package, :type => :model do
      let(:variant) { build(:variant, weight: 25.0) }
      let(:stock_location) { build(:stock_location) }
      let(:order) { build(:order) }

      subject { Package.new(stock_location) }

      def build_inventory_unit
        build(:inventory_unit, variant: variant)
      end

      it 'calculates the weight of all the contents' do
        4.times { subject.add build_inventory_unit }
        expect(subject.weight).to eq(100.0)
      end

      context "currency" do
        let(:unit) { build_inventory_unit }
        before { subject.add unit }

        it "returns the currency based on the currency from the order" do
          expect(subject.currency).to eql "USD"
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

      # Contains regression test for #2804
      it 'builds a list of shipping methods common to all categories' do
        category1 = create(:shipping_category)
        category2 = create(:shipping_category)
        method1   = create(:shipping_method)
        method2   = create(:shipping_method)
        method1.shipping_categories = [category1, category2]
        method2.shipping_categories = [category1]
        variant1 = mock_model(Variant, shipping_category: category1)
        variant2 = mock_model(Variant, shipping_category: category2)
        variant3 = mock_model(Variant, shipping_category: nil)
        contents = [ContentItem.new(build(:inventory_unit, variant: variant1)),
                    ContentItem.new(build(:inventory_unit, variant: variant1)),
                    ContentItem.new(build(:inventory_unit, variant: variant2)),
                    ContentItem.new(build(:inventory_unit, variant: variant3))]

        package = Package.new(stock_location, contents)
        expect(package.shipping_methods).to eq([method1])
      end

      it 'builds an empty list of shipping methods when no categories' do
        variant  = mock_model(Variant, shipping_category: nil)
        contents = [ContentItem.new(build(:inventory_unit, variant: variant))]
        package  = Package.new(stock_location, contents)
        expect(package.shipping_methods).to be_empty
      end

      it "can convert to a shipment" do
        2.times { subject.add build_inventory_unit }
        subject.add build_inventory_unit, :backordered

        shipping_method = build(:shipping_method)
        subject.shipping_rates = [ Spree::ShippingRate.new(shipping_method: shipping_method, cost: 10.00, selected: true) ]

        shipment = subject.to_shipment
        expect(shipment.stock_location).to eq subject.stock_location
        expect(shipment.inventory_units.size).to eq 3

        first_unit = shipment.inventory_units.first
        expect(first_unit.variant).to eq variant
        expect(first_unit.state).to eq 'on_hand'
        expect(first_unit).to be_pending

        last_unit = shipment.inventory_units.last
        expect(last_unit.variant).to eq variant
        expect(last_unit.state).to eq 'backordered'

        expect(shipment.shipping_method).to eq shipping_method
      end

      it 'does not add an inventory unit to a package twice' do
        # since inventory units currently don't have a quantity
        unit = build_inventory_unit
        subject.add unit
        subject.add unit
        expect(subject.quantity).to eq 1
        expect(subject.contents.first.inventory_unit).to eq unit
        expect(subject.contents.first.quantity).to eq 1
      end

      describe "#add_multiple" do
        it "adds multiple inventory units" do
          expect { subject.add_multiple [build_inventory_unit, build_inventory_unit] }.to change { subject.quantity }.by(2)
        end

        it "allows adding with a state" do
          expect { subject.add_multiple [build_inventory_unit, build_inventory_unit], :backordered }.to change { subject.backordered.count }.by(2)
        end

        it "defaults to adding with the on hand state" do
          expect { subject.add_multiple [build_inventory_unit, build_inventory_unit] }.to change { subject.on_hand.count }.by(2)
        end
      end

      describe "#remove" do
        let(:unit) { build_inventory_unit }
        context "there is a content item for the inventory unit" do

          before { subject.add unit }

          it "removes that content item" do
            expect { subject.remove(unit) }.to change { subject.quantity }.by(-1)
            expect(subject.contents.map(&:inventory_unit)).not_to include unit
          end
        end

        context "there is no content item for the inventory unit" do
          it "doesn't change the set of content items" do
            expect { subject.remove(unit) }.not_to change { subject.quantity }
          end
        end
      end

      describe "#order" do
        let(:unit) { build_inventory_unit }
        context "there is an inventory unit" do

          before { subject.add unit }

          it "returns an order" do
            expect(subject.order).to be_a_kind_of Spree::Order
            expect(subject.order).to eq unit.order
          end
        end

        context "there is no inventory unit" do
          it "returns nil" do
            expect(subject.order).to eq nil
          end
        end
      end

      context "#volume" do
        it "calculates the sum of the volume of all the items" do
          contents = [ContentItem.new(build(:inventory_unit, variant: build(:variant))),
                      ContentItem.new(build(:inventory_unit, variant: build(:variant))),
                      ContentItem.new(build(:inventory_unit, variant: build(:variant))),
                      ContentItem.new(build(:inventory_unit, variant: build(:variant)))]
          package = Package.new(stock_location, contents)
          expect(package.volume).to eq contents.sum(&:volume)
        end
      end

      context "#dimension" do
        it "calculates the sum of the dimension of all the items" do
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
