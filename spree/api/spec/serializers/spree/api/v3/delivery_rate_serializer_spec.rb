require 'spec_helper'

RSpec.describe Spree::Api::V3::DeliveryRateSerializer do
  let(:store) { @default_store }
  let(:base_params) { { store: store, currency: store.default_currency } }

  let(:shipment) { create(:shipment) }
  let(:shipping_rate) { shipment.shipping_rates.first }

  subject { described_class.new(shipping_rate, params: base_params).to_h }

  describe 'serialized attributes' do
    it 'includes all expected attributes' do
      expect(subject.keys).to match_array(%w[
        id delivery_method_id name selected
        cost display_cost total display_total
        additional_tax_total display_additional_tax_total
        included_tax_total display_included_tax_total
        tax_total display_tax_total
        delivery_method
      ])
    end

    it 'returns cost and total' do
      expect(subject['cost']).to eq(shipping_rate.cost)
      expect(subject['total']).to eq(shipping_rate.total)
    end

    it 'returns display_cost and display_total' do
      expect(subject['display_cost']).to be_present
      expect(subject['display_total']).to be_present
    end

    it 'returns tax totals as zero when no tax rate' do
      expect(subject['tax_total']).to eq(0)
      expect(subject['additional_tax_total']).to eq(0)
      expect(subject['included_tax_total']).to eq(0)
    end

    it 'returns prefixed delivery_method_id' do
      expect(subject['delivery_method_id']).to eq(shipping_rate.shipping_method.prefixed_id)
    end
  end

  context 'with additional tax' do
    let(:tax_rate) { create(:tax_rate, amount: 0.1, included_in_price: false) }

    before { shipping_rate.update!(tax_rate: tax_rate) }

    it 'returns the tax in additional_tax_total' do
      expect(subject['tax_total']).to be > 0
      expect(subject['additional_tax_total']).to be > 0
      expect(subject['included_tax_total']).to eq(0)
    end
  end

  context 'with included tax' do
    let!(:default_zone) { create(:zone, default_tax: true) }
    let(:tax_rate) { create(:tax_rate, amount: 0.1, included_in_price: true, zone: default_zone) }

    before { shipping_rate.update!(tax_rate: tax_rate) }

    it 'returns the tax in included_tax_total' do
      expect(subject['tax_total']).to be > 0
      expect(subject['additional_tax_total']).to eq(0)
      expect(subject['included_tax_total']).to be > 0
    end
  end

  context 'with free shipping promotion' do
    let(:free_shipping_promotion) { create(:free_shipping_promotion, code: 'freeship', kind: :coupon_code) }
    let(:order) { shipment.order }

    before do
      order.coupon_code = free_shipping_promotion.code
      Spree::PromotionHandler::Coupon.new(order).apply
      shipping_rate.reload
    end

    it 'returns total as 0' do
      expect(subject['total']).to eq(0)
    end

    it 'returns display_total as $0.00' do
      expect(subject['display_total']).to eq('$0.00')
    end

    it 'preserves original cost' do
      expect(subject['cost']).to be > 0
    end
  end
end
