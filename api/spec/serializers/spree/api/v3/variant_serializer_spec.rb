require 'spec_helper'

RSpec.describe Spree::Api::V3::VariantSerializer do
  let(:store) { @default_store }
  let(:product) { create(:product, stores: [store]) }
  let(:variant) { create(:variant, product: product) }
  let(:base_params) { { store: store, currency: 'USD' } }

  describe 'store serializer' do
    subject { described_class.new(variant, params: base_params).to_h }

    it 'includes standard attributes' do
      expect(subject).to include(
        'id' => variant.prefix_id,
        'sku' => variant.sku,
        'product_id' => product.prefix_id
      )
      expect(subject).to have_key('price')
      expect(subject).to have_key('original_price')
    end

    it 'does not include admin-only attributes' do
      expect(subject.keys).not_to include('cost_price', 'cost_currency', 'total_on_hand', 'deleted_at', 'barcode')
    end
  end
end

RSpec.describe Spree::Api::V3::Admin::VariantSerializer do
  let(:store) { @default_store }
  let(:product) { create(:product, stores: [store]) }
  let(:variant) { create(:variant, product: product) }
  let(:base_params) { { store: store, currency: 'USD' } }

  describe 'admin serializer' do
    subject { described_class.new(variant, params: base_params).to_h }

    it 'includes admin-only attributes' do
      expect(subject.keys).to include('cost_price', 'cost_currency', 'total_on_hand', 'deleted_at')
    end

    it 'includes prices array when included' do
      result = described_class.new(variant, params: base_params.merge(includes: ['prices'])).to_h
      expect(result['prices']).to be_an(Array)
    end
  end
end
