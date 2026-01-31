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
        'amount' => 19.99,
        'amount_in_cents' => 1999,
        'display_amount' => '$19.99'
      )
    end

    it 'includes currency' do
      expect(subject['currency']).to eq('USD')
    end

    it 'includes nil compare_at_amount when not set' do
      expect(subject['compare_at_amount']).to be_nil
      expect(subject['compare_at_amount_in_cents']).to be_nil
      expect(subject['display_compare_at_amount']).to be_nil
    end

    it 'includes nil price_list_id when no price list' do
      expect(subject['price_list_id']).to be_nil
    end

    context 'with compare_at_amount set' do
      before do
        price.update!(compare_at_amount: 29.99)
      end

      it 'includes compare_at_amount fields' do
        expect(subject).to include(
          'compare_at_amount' => 29.99,
          'compare_at_amount_in_cents' => 2999,
          'display_compare_at_amount' => '$29.99'
        )
      end
    end

    context 'with price list' do
      let(:price_list) { create(:price_list, :active, store: store) }
      let(:price) { create(:price, variant: variant, amount: 14.99, currency: 'USD', price_list: price_list) }

      it 'includes price_list_id' do
        expect(subject['price_list_id']).to eq(price_list.prefix_id)
      end
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

    it 'includes store price attributes' do
      expect(subject).to include(
        'amount' => 19.99,
        'amount_in_cents' => 1999,
        'display_amount' => '$19.99',
        'currency' => 'USD'
      )
    end

    it 'includes admin-only variant_id' do
      expect(subject['variant_id']).to eq(variant.prefix_id)
    end

    it 'includes timestamps' do
      expect(subject).to have_key('created_at')
      expect(subject).to have_key('updated_at')
    end
  end
end
