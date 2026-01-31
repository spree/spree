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
    end

    it 'includes timestamps' do
      expect(subject).to have_key('created_at')
      expect(subject).to have_key('updated_at')
    end

    it 'does not include admin-only attributes' do
      expect(subject).not_to have_key('cost_price')
      expect(subject).not_to have_key('cost_currency')
      expect(subject).not_to have_key('private_metadata')
      expect(subject).not_to have_key('total_on_hand')
      expect(subject).not_to have_key('deleted_at')
      expect(subject).not_to have_key('barcode')
    end

    describe 'price object' do
      let(:variant) { create(:variant, product: product, price: 19.99) }

      it 'includes price as a nested object' do
        expect(subject['price']).to include(
          'amount' => 19.99,
          'display_amount' => '$19.99',
          'currency' => 'USD'
        )
        expect(subject['price']['amount_in_cents']).to eq(1999)
      end

      it 'includes original_price as a nested object' do
        expect(subject['original_price']).to include(
          'amount' => 19.99,
          'display_amount' => '$19.99',
          'currency' => 'USD'
        )
        expect(subject['original_price']['amount_in_cents']).to eq(1999)
      end

      it 'includes price_list_id as nil when no price list' do
        expect(subject['price']['price_list_id']).to be_nil
      end

      context 'with compare_at_price set' do
        before do
          variant.prices.first.update!(compare_at_amount: 29.99)
        end

        it 'includes compare_at_amount in price object' do
          expect(subject['price']).to include(
            'compare_at_amount' => 29.99,
            'display_compare_at_amount' => '$29.99'
          )
          expect(subject['price']['compare_at_amount_in_cents']).to eq(2999)
        end

      end

      context 'with price list applied' do
        let(:price_list) { create(:price_list, :active, store: store) }

        before do
          create(:price, variant: variant, amount: 14.99, currency: 'USD', price_list: price_list)
        end

        it 'returns price list price as the main price' do
          expect(subject['price']['amount']).to eq(14.99)
          expect(subject['price']['display_amount']).to eq('$14.99')
        end

        it 'returns base price as original_price' do
          expect(subject['original_price']['amount']).to eq(19.99)
          expect(subject['original_price']['display_amount']).to eq('$19.99')
        end

        it 'includes the price_list_id in price object' do
          expect(subject['price']['price_list_id']).to eq(price_list.prefix_id)
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

    it 'includes standard attributes' do
      expect(subject).to include(
        'id' => variant.prefix_id,
        'sku' => variant.sku,
        'product_id' => product.prefix_id
      )
    end

    it 'includes admin-only attributes' do
      expect(subject).to have_key('cost_price')
      expect(subject).to have_key('cost_currency')
      expect(subject).to have_key('total_on_hand')
      expect(subject).to have_key('deleted_at')
    end

    context 'with prices include' do
      subject { described_class.new(variant, params: base_params.merge(includes: ['prices'])).to_h }

      it 'includes prices array' do
        expect(subject).to have_key('prices')
        expect(subject['prices']).to be_an(Array)
      end
    end
  end
end
