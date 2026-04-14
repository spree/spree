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

  let(:order) { create(:order_ready_to_ship, store: store) }
  let(:shipment) { order.shipments.first }

  subject { described_class.new(shipment, params: params).to_h }

  describe 'serialized attributes' do
    it 'includes cost and total fields' do
      expect(subject).to include(
        'cost' => shipment.cost,
        'total' => shipment.total
      )
      expect(subject['display_cost']).to be_present
      expect(subject['display_total']).to be_present
    end

    it 'includes discount_total' do
      expect(subject).to have_key('discount_total')
      expect(subject).to have_key('display_discount_total')
    end

    it 'includes tax fields' do
      expect(subject).to have_key('additional_tax_total')
      expect(subject).to have_key('display_additional_tax_total')
      expect(subject).to have_key('included_tax_total')
      expect(subject).to have_key('display_included_tax_total')
      expect(subject).to have_key('tax_total')
      expect(subject).to have_key('display_tax_total')
    end

    it 'includes standard fulfillment attributes' do
      expect(subject).to include(
        'id' => shipment.prefixed_id,
        'number' => shipment.number,
        'status' => shipment.state,
        'fulfillment_type' => 'shipping'
      )
    end

    it 'returns status mapped from state' do
      expect(subject['status']).to eq(shipment.state)
    end
  end

  describe '#items' do
    it 'serializes manifest items with prefixed IDs' do
      items = subject['items']
      expect(items).to be_an(Array)
      expect(items.length).to be >= 1

      item = items.first
      item_id = item[:item_id] || item['item_id']
      variant_id = item[:variant_id] || item['variant_id']
      qty = item[:quantity] || item['quantity']

      expect(item_id).to be_present
      expect(variant_id).to be_present
      expect(qty).to be_a(Integer)
    end

    context 'when a line item has been deleted' do
      before do
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

  context 'with free shipping promotion' do
    let(:free_shipping_promotion) { create(:free_shipping_promotion, code: 'freeship', kind: :coupon_code) }
    let(:bare_shipment) { create(:shipment) }
    let(:bare_order) { bare_shipment.order }

    subject { described_class.new(bare_shipment, params: params).to_h }

    before do
      bare_order.coupon_code = free_shipping_promotion.code
      Spree::PromotionHandler::Coupon.new(bare_order).apply
      bare_order.updater.update
      bare_shipment.reload
    end

    it 'returns discount_total reflecting the promotion' do
      expect(subject['cost']).to be > 0
      expect(subject['discount_total']).to be < 0
    end
  end
end
