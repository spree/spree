require 'spec_helper'

describe Spree::FulfillmentItem, type: :model do
  let(:stock_location) { create(:stock_location_with_items) }
  let(:stock_level) { stock_location.stock_levels.order(:id).first }

  describe 'scopes' do
    let!(:inventory_unit_1) { create(:fulfillment_item, state: 'on_hand') }
    let!(:inventory_unit_2) { create(:fulfillment_item, state: 'backordered') }
    let!(:inventory_unit_3) { create(:fulfillment_item, state: 'shipped') }
    let!(:inventory_unit_4) { create(:fulfillment_item, state: 'returned') }

    describe '.on_hand_or_backordered' do
      it { expect(Spree::FulfillmentItem.on_hand_or_backordered).to match_array([inventory_unit_1, inventory_unit_2]) }
    end
  end

  describe '#backordered_for_stock_level' do
    let(:order) do
      order = create(:order, state: 'complete', ship_address: create(:ship_address))
      order.completed_at = Time.current
      create(:fulfillment, order: order, stock_location: stock_location)
      order.shipments.reload
      create(:line_item, order: order, variant: stock_level.variant)
      order.line_items.reload
      order.tap(&:save!)
    end

    let(:shipment) do
      order.fulfillments.first
    end

    let!(:unit) do
      unit = shipment.inventory_units.first
      unit.state = 'backordered'
      unit.tap(&:save!)
    end

    # A shelf below zero is legacy fixture state now — only a departure may
    # write one — so it is set on the column directly.
    before do
      stock_level.update_column(:count_on_hand, -2)
    end

    # Regression for #3066
    it 'returns modifiable objects' do
      units = Spree::FulfillmentItem.backordered_for_stock_level(stock_level)
      expect { units.first.save! }.not_to raise_error
    end

    it "finds inventory units from its stock location when the unit's variant matches the stock item's variant" do
      expect(Spree::FulfillmentItem.backordered_for_stock_level(stock_level)).to match_array([unit])
    end

    it "does not find inventory units that aren't backordered" do
      on_hand_unit = shipment.inventory_units.build
      on_hand_unit.state = 'on_hand'
      on_hand_unit.variant = create(:variant)
      on_hand_unit.line_item = order.line_items.first
      on_hand_unit.save!

      expect(Spree::FulfillmentItem.backordered_for_stock_level(stock_level)).not_to include(on_hand_unit)
    end

    it "does not find inventory units that don't match the stock item's variant" do
      other_variant_unit = shipment.inventory_units.build
      other_variant_unit.state = 'backordered'
      other_variant_unit.variant = create(:variant)
      other_variant_unit.line_item = order.line_items.first
      other_variant_unit.save!

      expect(Spree::FulfillmentItem.backordered_for_stock_level(stock_level)).not_to include(other_variant_unit)
    end

    context 'other shipments' do
      let(:other_order) do
        order = create(:order)
        order.completed_at = nil
        create(:line_item, order: order, variant: stock_level.variant)
        order.line_items.reload
        order.tap(&:save!)
      end

      let(:other_shipment) do
        shipment = Spree::Fulfillment.new
        shipment.stock_location = stock_location
        shipment.shipping_methods << create(:delivery_method)
        shipment.order = other_order
        # We don't care about this in this test
        allow(shipment).to receive(:ensure_correct_adjustment)
        shipment.tap(&:save!)
      end

      let!(:other_unit) do
        unit = other_shipment.inventory_units.build
        unit.state = 'backordered'
        unit.variant_id = stock_level.variant.id
        unit.order_id = other_order.id
        unit.line_item = other_order.line_items.first
        unit.tap(&:save!)
      end

      it 'does not find inventory units belonging to incomplete orders' do
        expect(Spree::FulfillmentItem.backordered_for_stock_level(stock_level)).not_to include(other_unit)
      end
    end
  end

  describe '#finalize_units!' do
    let(:variant) { create(:variant) }
    let (:shipment) { create(:fulfillment) }
    let(:inventory_units) do
      [
        create(:fulfillment_item, variant: variant),
        create(:fulfillment_item, variant: variant)
      ]
    end

    before do
      shipment.inventory_units = inventory_units
    end

    it 'creates a stock movement' do
      expect { shipment.inventory_units.finalize_units! }.
        to change { shipment.inventory_units.where(pending: false).count }.by 2
    end
  end

  describe '#additional_tax_total' do
    subject do
      build(:fulfillment_item, line_item: line_item)
    end

    let(:quantity) { 2 }
    let(:line_item_additional_tax_total) { 10.00 }
    let(:line_item) do
      build(:line_item,         quantity: quantity,
                                additional_tax_total: line_item_additional_tax_total)
    end

    it 'is the correct amount' do
      expect(subject.additional_tax_total).to eq line_item_additional_tax_total / quantity
    end
  end

  describe '#included_tax_total' do
    subject do
      build(:fulfillment_item, line_item: line_item)
    end

    let(:quantity) { 2 }
    let(:line_item_included_tax_total) { 10.00 }
    let(:line_item) do
      build(:line_item,         quantity: quantity,
                                included_tax_total: line_item_included_tax_total)
    end

    it 'is the correct amount' do
      expect(subject.included_tax_total).to eq line_item_included_tax_total / quantity
    end
  end

  describe '#charged_amount' do
    subject { build(:fulfillment_item, line_item: line_item, quantity: 1) }

    let(:quantity) { 2 }
    let(:line_item_pre_tax_amount) { 10.00 }
    let(:line_item) { build(:line_item, quantity: quantity, pre_tax_amount: line_item_pre_tax_amount) }

    it 'is the correct amount' do
      expect(subject.charged_amount).to eq line_item_pre_tax_amount / quantity
    end
  end
end
