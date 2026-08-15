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
        carrier service_level estimated_delivery_date
        delivery_method
      ])
    end

    # Carrier fields are populated by rate providers; calculator-priced
    # methods leave them nil rather than omitting the keys.
    it 'exposes carrier fields as null when the rate has none' do
      expect(subject['carrier']).to be_nil
      expect(subject['service_level']).to be_nil
      expect(subject['estimated_delivery_date']).to be_nil
    end

    it 'exposes carrier fields set by a provider' do
      shipping_rate.update!(carrier: 'UPS', service_level: 'Ground', estimated_delivery_date: Date.new(2026, 8, 20))

      expect(subject['carrier']).to eq('UPS')
      expect(subject['service_level']).to eq('Ground')
      expect(subject['estimated_delivery_date']).to eq(Date.new(2026, 8, 20))
    end

    # Provider payload is operational detail; customers must never see it.
    it 'does not expose provider metadata' do
      expect(subject.keys).not_to include('metadata')
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
      expect(subject['delivery_method_id']).to eq(shipping_rate.delivery_method.prefixed_id)
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
    let(:tax_rate) { create(:tax_rate, amount: 0.1, included_in_price: true, country_code: @default_country&.iso) }

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
