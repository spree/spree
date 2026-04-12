require 'spec_helper'

RSpec.describe Spree::Api::V3::DeliveryRateSerializer do
  let(:store) { @default_store }
  let(:shipping_rate) { create(:shipping_rate) }
  let(:base_params) { { store: store, currency: store.default_currency } }

  subject { described_class.new(shipping_rate, params: base_params).to_h }

  describe 'serialized attributes' do
    it 'includes standard attributes' do
      expect(subject).to include(
        'id' => shipping_rate.prefixed_id,
        'name' => shipping_rate.name,
        'selected' => shipping_rate.selected
      )
    end

    it 'returns prefixed delivery_method_id' do
      expect(subject['delivery_method_id']).to eq(shipping_rate.shipping_method.prefixed_id)
    end

    it 'includes cost attributes' do
      expect(subject).to have_key('cost')
      expect(subject).to have_key('display_cost')
    end

    it 'includes final_price attributes' do
      expect(subject).to have_key('final_price')
      expect(subject).to have_key('display_final_price')
    end

    it 'exposes final_price from the model' do
      expect(subject['final_price']).to eq(shipping_rate.final_price)
    end

    it 'exposes display_final_price as a string' do
      expect(subject['display_final_price']).to eq(shipping_rate.display_final_price.to_s)
    end

    it 'exposes free as a boolean' do
      expect(subject['free']).to eq(shipping_rate.free?)
    end

    it 'does not include timestamps in Store API' do
      expect(subject).not_to have_key('created_at')
      expect(subject).not_to have_key('updated_at')
    end
  end

  describe 'with a free shipping promotion' do
    before do
      allow(shipping_rate).to receive(:with_free_shipping_promotion?).and_return(true)
    end

    it 'returns final_price as zero' do
      expect(subject['final_price']).to eq(BigDecimal(0))
    end

    it 'returns free as true' do
      expect(subject['free']).to be true
    end
  end
end
