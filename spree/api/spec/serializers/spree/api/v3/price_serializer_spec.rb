require 'spec_helper'

RSpec.describe Spree::Api::V3::PriceSerializer do
  let(:store) { @default_store }
  let(:product) { create(:product, stores: [store], price: 19.99) }
  let(:variant) { product.master }
  let(:price) { variant.prices.first }
  let(:base_params) { { store: store, currency: 'USD' } }

  describe 'store serializer' do
    subject { described_class.new(price, params: base_params).to_h }

    it 'includes amount fields' do
      expect(subject).to include(
        'amount' => '19.99'.to_d,
        'amount_in_cents' => 1999,
        'display_amount' => '$19.99',
        'currency' => 'USD'
      )
    end

    it 'includes nil compare_at fields when not set' do
      expect(subject.values_at('compare_at_amount', 'compare_at_amount_in_cents', 'display_compare_at_amount')).to all(be_nil)
    end

    it 'includes compare_at fields when set' do
      price.update!(compare_at_amount: 29.99)
      expect(subject).to include(
        'compare_at_amount' => '29.99'.to_d,
        'compare_at_amount_in_cents' => 2999,
        'display_compare_at_amount' => '$29.99'
      )
    end

    it 'includes price_list_id when price list is set' do
      price_list = create(:price_list, :active, store: store)
      price_with_list = create(:price, variant: variant, amount: 14.99, currency: 'USD', price_list: price_list)
      result = described_class.new(price_with_list, params: base_params).to_h
      expect(result['price_list_id']).to eq(price_list.prefixed_id)
    end
  end
end

RSpec.describe Spree::Api::V3::Admin::PriceSerializer do
  let(:store) { @default_store }
  let(:product) { create(:product, stores: [store], price: 19.99) }
  let(:variant) { product.master }
  let(:price) { variant.prices.first }
  let(:base_params) { { store: store, currency: 'USD' } }

  describe 'admin serializer' do
    subject { described_class.new(price, params: base_params).to_h }

    it 'includes admin-only variant_id and timestamps' do
      expect(subject['variant_id']).to eq(variant.prefixed_id)
      expect(subject.keys).to include('created_at', 'updated_at')
    end
  end
end
