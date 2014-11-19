require 'spec_helper'

module Spree
  module Stock
    describe Package, :type => :model do
      let(:variant) { build(:variant, weight: 25.0) }
      let(:line_item) { build(:line_item, variant: variant) }
      let(:stock_location) { build(:stock_location) }
      let(:order) { build(:order) }

      subject { Package.new(stock_location, order) }

      it 'calculates the weight of all the contents' do
        subject.add line_item, 4
        expect(subject.weight).to eq(100.0)
      end

      it 'filters by on_hand and backordered' do
        subject.add line_item, 4, :on_hand
        subject.add line_item, 3, :backordered
        expect(subject.on_hand.count).to eq 1
        expect(subject.backordered.count).to eq 1
      end

      it 'calculates the quantity by state' do
        subject.add line_item, 4, :on_hand
        subject.add line_item, 3, :backordered

        expect(subject.quantity).to eq 7
        expect(subject.quantity(:on_hand)).to eq 4
        expect(subject.quantity(:backordered)).to eq 3
      end

      it 'returns nil for content item not found' do
        item = subject.find_item(variant, :on_hand)
        expect(item).to be_nil
      end

      it 'finds content item for a variant' do
        subject.add line_item, 4, :on_hand
        item = subject.find_item(variant, :on_hand)
        expect(item.quantity).to eq 4
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
        contents = [Package::ContentItem.new(line_item, variant1, 1),
                    Package::ContentItem.new(line_item, variant1, 1),
                    Package::ContentItem.new(line_item, variant2, 1),
                    Package::ContentItem.new(line_item, variant3, 1)]

        package = Package.new(stock_location, order, contents)
        expect(package.shipping_methods).to eq([method1])
      end

      it 'builds an empty list of shipping methods when no categories' do
        variant  = mock_model(Variant, shipping_category: nil)
        contents = [Package::ContentItem.new(line_item, variant, 1)]
        package  = Package.new(stock_location, order, contents)
        expect(package.shipping_methods).to be_empty
      end

      it "can convert to a shipment" do
        subject.add line_item, 2, :on_hand, variant
        subject.add line_item, 1, :backordered, variant

        shipping_method = build(:shipping_method)
        subject.shipping_rates = [ Spree::ShippingRate.new(shipping_method: shipping_method, cost: 10.00, selected: true) ]

        shipment = subject.to_shipment
        expect(shipment.address).to eq subject.order.ship_address
        expect(shipment.order).to eq subject.order
        expect(shipment.stock_location).to eq subject.stock_location
        expect(shipment.inventory_units.size).to eq 3

        first_unit = shipment.inventory_units.first
        expect(first_unit.variant).to eq variant
        expect(first_unit.state).to eq 'on_hand'
        expect(first_unit.order).to eq subject.order
        expect(first_unit).to be_pending

        last_unit = shipment.inventory_units.last
        expect(last_unit.variant).to eq variant
        expect(last_unit.state).to eq 'backordered'
        expect(last_unit.order).to eq subject.order

        expect(shipment.shipping_method).to eq shipping_method
      end

      context "line item and variant don't refer same product" do
        let(:other_variant) { build(:variant) }

        before { subject.add(line_item, 4, :on_hand, other_variant) }

        it "cant find the item given wrong variant" do
          expect(subject.find_item(variant, :on_hand)).to be_nil
        end

        it "finds the item when given proper variant and line item" do
          expect(subject.find_item(other_variant, :on_hand)).to eq subject.contents.last
          expect(subject.find_item(other_variant, :on_hand, line_item)).to eq subject.contents.last
        end
      end
    end
  end
end
