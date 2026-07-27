require 'spec_helper'

RSpec.describe Spree::Api::V3::FulfillmentSerializer do
  let(:store) { @default_store }
  let(:params) do
    {
      store: store,
      locale: 'en',
      currency: store.default_currency,
      user: nil,
      includes: [],
      expand: []
    }
  end

  describe '#items' do
    let(:order) { create(:order_ready_to_ship, store: store) }
    let(:shipment) { order.shipments.first }

    it 'serializes manifest items with prefixed IDs' do
      result = described_class.new(shipment, params: params).to_h

      items = result['items']
      expect(items).to be_an(Array)
      expect(items.length).to be >= 1

      item = items.first
      # Alba with oj_rails returns string keys at top level but symbol keys in nested hashes
      item_id = item[:item_id] || item['item_id']
      variant_id = item[:variant_id] || item['variant_id']
      qty = item[:quantity] || item['quantity']

      expect(item_id).to be_present
      expect(variant_id).to be_present
      expect(qty).to be_a(Integer)
    end

    context 'when a line item has been deleted' do
      before do
        # Delete the line item directly so the manifest still references it
        # but the record no longer exists (simulates the after_commit race)
        line_item = shipment.line_items.first
        line_item.delete
        shipment.reload
      end

      it 'skips manifest entries with nil line_item without raising' do
        expect {
          result = described_class.new(shipment, params: params).to_h
          expect(result['items']).to be_an(Array)
        }.not_to raise_error
      end
    end
  end

  describe 'attributes' do
    let(:order) { create(:order_ready_to_ship, store: store) }
    let(:shipment) { order.shipments.first }

    it 'includes expected fields' do
      result = described_class.new(shipment, params: params).to_h

      expect(result).to include(
        'id', 'number', 'status', 'tracking', 'cost', 'display_cost', 'items'
      )
    end

    it 'returns status mapped from state' do
      result = described_class.new(shipment, params: params).to_h
      expect(result['status']).to eq(shipment.state)
    end
  end

  describe 'nested adjustment lines' do
    let(:order) { create(:order_ready_to_ship, store: store) }
    let(:shipment) { order.shipments.first }
    let!(:tax_line) { create(:tax_line, line_item: nil, fulfillment: shipment, order: order, amount: 0.4, label: 'Sales Tax', included: false) }
    let!(:discount_line) { create(:discount_line, line_item: nil, fulfillment: shipment, order: order, amount: -5.0, label: 'Free shipping') }

    it 'embeds the fulfillment tax and discount lines' do
      result = described_class.new(shipment, params: params).to_h

      expect(result['tax_lines'].sole).to include('amount' => '0.4', 'label' => 'Sales Tax', 'included' => false)
      expect(result['discount_lines'].sole).to include('amount' => '-5.0', 'label' => 'Free shipping')
    end

    context 'when prices are hidden' do
      let(:params) { super().merge(hide_prices: true) }

      it 'omits the lines entirely' do
        result = described_class.new(shipment, params: params).to_h

        expect(result).not_to have_key('tax_lines')
        expect(result).not_to have_key('discount_lines')
      end
    end
  end
end
