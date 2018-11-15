require 'spec_helper'

describe Spree::InventoryUnit, type: :model do
  let(:stock_location) { create(:stock_location_with_items) }
  let(:stock_item) { stock_location.stock_items.order(:id).first }

  describe 'scopes' do
    let!(:inventory_unit_1) { create(:inventory_unit, state: 'on_hand') }
    let!(:inventory_unit_2) { create(:inventory_unit, state: 'backordered') }
    let!(:inventory_unit_3) { create(:inventory_unit, state: 'shipped') }
    let!(:inventory_unit_4) { create(:inventory_unit, state: 'returned') }

    describe '.backordered' do
      it { expect(Spree::InventoryUnit.backordered).to eq([inventory_unit_2]) }
    end

    describe '.on_hand' do
      it { expect(Spree::InventoryUnit.on_hand).to eq([inventory_unit_1]) }
    end

    describe '.on_hand_or_backordered' do
      it { expect(Spree::InventoryUnit.on_hand_or_backordered).to match_array([inventory_unit_1, inventory_unit_2]) }
    end

    describe '.shipped' do
      it { expect(Spree::InventoryUnit.shipped).to eq([inventory_unit_3]) }
    end

    describe '.returned' do
      it { expect(Spree::InventoryUnit.returned).to eq([inventory_unit_4]) }
    end
  end

  context '#backordered_for_stock_item' do
    let(:order) do
      order = create(:order, state: 'complete', ship_address: create(:ship_address))
      order.completed_at = Time.current
      create(:shipment, order: order, stock_location: stock_location)
      order.shipments.reload
      create(:line_item, order: order, variant: stock_item.variant)
      order.line_items.reload
      order.tap(&:save!)
    end

    let(:shipment) do
      order.shipments.first
    end

    let(:shipping_method) do
      shipment.shipping_methods.first
    end

    let!(:unit) do
      unit = shipment.inventory_units.first
      unit.state = 'backordered'
      unit.tap(&:save!)
    end

    before do
      stock_item.set_count_on_hand(-2)
    end

    # Regression for #3066
    it 'returns modifiable objects' do
      units = Spree::InventoryUnit.backordered_for_stock_item(stock_item)
      expect { units.first.save! }.not_to raise_error
    end

    it "finds inventory units from its stock location when the unit's variant matches the stock item's variant" do
      expect(Spree::InventoryUnit.backordered_for_stock_item(stock_item)).to match_array([unit])
    end

    it "does not find inventory units that aren't backordered" do
      on_hand_unit = shipment.inventory_units.build
      on_hand_unit.state = 'on_hand'
      on_hand_unit.variant_id = 1
      on_hand_unit.save!

      expect(Spree::InventoryUnit.backordered_for_stock_item(stock_item)).not_to include(on_hand_unit)
    end

    it "does not find inventory units that don't match the stock item's variant" do
      other_variant_unit = shipment.inventory_units.build
      other_variant_unit.state = 'backordered'
      other_variant_unit.variant = create(:variant)
      other_variant_unit.save!

      expect(Spree::InventoryUnit.backordered_for_stock_item(stock_item)).not_to include(other_variant_unit)
    end

    it 'does not change shipping cost when fulfilling the order' do
      current_shipment_cost = shipment.cost
      shipping_method.calculator.set_preference(:amount, current_shipment_cost + 5.0)
      stock_item.set_count_on_hand(0)
      expect(shipment.reload.cost).to eq(current_shipment_cost)
    end

    context 'other shipments' do
      let(:other_order) do
        order = create(:order)
        order.state = 'payment'
        order.completed_at = nil
        order.tap(&:save!)
      end

      let(:other_shipment) do
        shipment = Spree::Shipment.new
        shipment.stock_location = stock_location
        shipment.shipping_methods << create(:shipping_method)
        shipment.order = other_order
        # We don't care about this in this test
        allow(shipment).to receive(:ensure_correct_adjustment)
        shipment.tap(&:save!)
      end

      let!(:other_unit) do
        unit = other_shipment.inventory_units.build
        unit.state = 'backordered'
        unit.variant_id = stock_item.variant.id
        unit.order_id = other_order.id
        unit.tap(&:save!)
      end

      it 'does not find inventory units belonging to incomplete orders' do
        expect(Spree::InventoryUnit.backordered_for_stock_item(stock_item)).not_to include(other_unit)
      end
    end
  end

  context '#finalize_units!' do
    let!(:stock_location) { create(:stock_location) }
    let(:variant) { create(:variant) }
    let (:shipment) { create(:shipment) }
    let(:inventory_units) do
      [
        create(:inventory_unit, variant: variant),
        create(:inventory_unit, variant: variant)
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

  describe '#current_or_new_return_item' do
    subject { inventory_unit.current_or_new_return_item }

    before { allow(inventory_unit).to receive_messages(pre_tax_amount: 100.0) }

    context 'associated with a return item' do
      let(:return_item) { create(:return_item) }
      let(:inventory_unit) { return_item.inventory_unit }

      it 'returns a persisted return item' do
        expect(subject).to be_persisted
      end

      it "returns it's associated return_item" do
        expect(subject).to eq return_item
      end
    end

    context 'no associated return item' do
      let(:inventory_unit) { create(:inventory_unit) }

      it 'returns a new return item' do
        expect(subject).not_to be_persisted
      end

      it 'associates itself to the new return_item' do
        expect(subject.inventory_unit).to eq inventory_unit
      end
    end
  end

  describe '#additional_tax_total' do
    subject do
      build(:inventory_unit, line_item: line_item)
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
      build(:inventory_unit, line_item: line_item)
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

  describe '#additional_tax_total' do
    subject do
      build(:inventory_unit, line_item: line_item)
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
      build(:inventory_unit, line_item: line_item)
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
end
