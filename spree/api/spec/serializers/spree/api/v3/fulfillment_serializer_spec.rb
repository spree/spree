require 'spec_helper'

RSpec.describe Spree::Api::V3::FulfillmentSerializer do
  let(:store) { @default_store }
  let(:base_params) { { store: store, currency: store.default_currency } }

  let(:shipment) { create(:shipment) }

  subject { described_class.new(shipment, params: base_params).to_h }

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
  end

  context 'with free shipping promotion' do
    let(:free_shipping_promotion) { create(:free_shipping_promotion, code: 'freeship', kind: :coupon_code) }
    let(:order) { shipment.order }

    before do
      order.coupon_code = free_shipping_promotion.code
      Spree::PromotionHandler::Coupon.new(order).apply
      order.updater.update
      shipment.reload
    end

    it 'returns discount_total reflecting the promotion' do
      expect(subject['cost']).to be > 0
      expect(subject['discount_total']).to be < 0
    end
  end
end
