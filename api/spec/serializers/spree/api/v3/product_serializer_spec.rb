require 'spec_helper'

RSpec.describe Spree::Api::V3::ProductSerializer do
  let(:store) { @default_store }
  let(:product) { create(:product, stores: [store]) }
  let(:base_params) { { store: store, currency: 'USD' } }

  describe 'store serializer' do
    subject { described_class.new(product, params: base_params).to_h }

    it 'includes standard attributes' do
      expect(subject).to include(
        'id' => product.prefix_id,
        'name' => product.name,
        'slug' => product.slug,
        'default_variant_id' => product.default_variant.prefix_id
      )
      expect(subject).to have_key('thumbnail_url')
      expect(subject).to have_key('price')
    end

    it 'does not include admin-only attributes' do
      expect(subject.keys).not_to include('cost_price', 'cost_currency', 'deleted_at', 'sku', 'barcode')
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
        let!(:price_list_price) { create(:price, variant: product.default_variant, currency: 'USD', amount: 50.00, price_list: price_list) }

        before do
          # Set base price higher than price list price
          product.default_variant.prices.base_prices.find_by(currency: 'USD').update!(amount: 100.00)
        end

        it 'includes original_price when different from calculated price' do
          result = described_class.new(product, params: base_params.merge(price_list: price_list)).to_h
          expect(result['original_price']).not_to be_nil
          expect(result['original_price']['amount'].to_f).to eq(100.0)
          expect(result['price']['amount'].to_f).to eq(50.0)
        end
      end
    end

    describe 'metafields' do
      let(:public_definition) { create(:metafield_definition, resource_type: 'Spree::Product', display_on: 'both') }
      let(:private_definition) { create(:metafield_definition, :back_end_only, resource_type: 'Spree::Product') }
      let!(:public_metafield) { create(:metafield, resource: product, metafield_definition: public_definition, value: 'public') }
      let!(:private_metafield) { create(:metafield, resource: product, metafield_definition: private_definition, value: 'private') }

      it 'does not include metafields without include param' do
        expect(subject).not_to have_key('metafields')
      end

      it 'includes only public metafields with include param' do
        result = described_class.new(product, params: base_params.merge(includes: ['metafields'])).to_h
        expect(result['metafields'].length).to eq(1)
        expect(result['metafields'].first['value']).to eq('public')
      end
    end
  end
end

RSpec.describe Spree::Api::V3::Admin::ProductSerializer do
  let(:store) { @default_store }
  let(:product) { create(:product, stores: [store]) }
  let(:base_params) { { store: store, currency: 'USD' } }

  describe 'admin serializer' do
    subject { described_class.new(product, params: base_params).to_h }

    it 'includes admin-only attributes' do
      expect(subject.keys).to include('cost_price', 'cost_currency', 'deleted_at', 'status')
    end

    it 'includes all metafields with display_on when included' do
      public_def = create(:metafield_definition, resource_type: 'Spree::Product', display_on: 'both')
      private_def = create(:metafield_definition, :back_end_only, resource_type: 'Spree::Product')
      create(:metafield, resource: product, metafield_definition: public_def, value: 'public')
      create(:metafield, resource: product, metafield_definition: private_def, value: 'private')

      result = described_class.new(product, params: base_params.merge(includes: ['metafields'])).to_h
      expect(result['metafields'].length).to eq(2)
      expect(result['metafields']).to all(have_key('display_on'))
    end
  end
end
