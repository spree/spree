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
    let(:shipment) { order.fulfillments.first }

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

    context 'on a shipped order' do
      let(:order) { create(:shipped_order, store: store) }
      let(:unit) { shipment.fulfillment_items.first }

      before { Spree.hooks.register('returns.create.validate', 'Spree::Returns::ReturnableValidator') }

      def first_item
        described_class.new(shipment.reload, params: params.merge(returnability: true)).to_h['items'].first.deep_stringify_keys
      end

      # Only the Store order page asks for the customer's view.
      it 'leaves returnability out unless asked' do
        item = described_class.new(shipment, params: params).to_h['items'].first.deep_stringify_keys

        expect(item.keys).to contain_exactly('item_id', 'variant_id', 'quantity')
      end

      it 'names each unit and what the customer may still send back' do
        item = first_item

        expect(item['returnable_quantity']).to eq(unit.quantity)
        expect(item['non_returnable_reason']).to be_nil
        expect(item['units']).to contain_exactly(
          'fulfillment_item_id' => unit.prefixed_id, 'quantity' => unit.quantity,
          'returnable_quantity' => unit.quantity, 'non_returnable_reason' => nil
        )
      end

      it 'counts what already came back' do
        Spree::Returns::Create.call(order: order, items: [{ fulfillment_item: unit, quantity: unit.quantity }])

        expect(first_item).to include('returnable_quantity' => 0, 'non_returnable_reason' => 'already_returned')
      end

      it 'says when a line was sold as non-returnable' do
        unit.line_item.update_columns(returnable: false)

        expect(first_item).to include('returnable_quantity' => 0, 'non_returnable_reason' => 'not_returnable')
      end
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
    let(:shipment) { order.fulfillments.first }

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
end
