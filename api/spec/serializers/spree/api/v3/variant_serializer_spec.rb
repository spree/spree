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
    end

    it 'does not include admin-only attributes' do
      expect(subject.keys).not_to include('cost_price', 'cost_currency', 'total_on_hand', 'deleted_at', 'barcode')
    end

    describe 'original_price' do
      context 'without price list (base price only)' do
        it 'returns null when original_price equals calculated price' do
          expect(subject).to have_key('original_price')
          expect(subject['original_price']).to be_nil
        end
      end

      context 'with price list discount applied' do
        let(:price_list) { create(:price_list, :active, store: store) }
        let!(:price_list_price) { create(:price, variant: variant, currency: 'USD', amount: 50.00, price_list: price_list) }

        before do
          # Set base price higher than price list price
          variant.prices.base_prices.find_by(currency: 'USD').update!(amount: 100.00)
        end

        it 'includes original_price when different from calculated price' do
          result = described_class.new(variant, params: base_params.merge(price_list: price_list)).to_h
          expect(result['original_price']).not_to be_nil
          expect(result['original_price']['amount'].to_f).to eq(100.0)
          expect(result['price']['amount'].to_f).to eq(50.0)
        end
      end
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
