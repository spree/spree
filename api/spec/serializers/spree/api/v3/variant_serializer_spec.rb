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
    end

    describe 'price attributes' do
      let(:variant) { create(:variant, product: product, price: 19.99) }

      it 'includes price fields' do
        expect(subject).to include(
          'price' => 19.99,
          'display_price' => '$19.99'
        )
        expect(subject['price_in_cents']).to eq(1999)
      end

      it 'includes original_price fields' do
        expect(subject).to include(
          'original_price' => 19.99,
          'display_original_price' => '$19.99'
        )
        expect(subject['original_price_in_cents']).to eq(1999)
      end

      it 'includes on_sale as false when no discount' do
        expect(subject['on_sale']).to be false
      end

      it 'includes price_list_id as nil when no price list' do
        expect(subject['price_list_id']).to be_nil
      end

      context 'with compare_at_price set' do
        before do
          variant.prices.first.update!(compare_at_amount: 29.99)
        end

        it 'includes compare_at_price fields' do
          expect(subject).to include(
            'compare_at_price' => 29.99,
            'display_compare_at_price' => '$29.99'
          )
          expect(subject['compare_at_price_in_cents']).to eq(2999)
        end

        it 'sets on_sale to true' do
          expect(subject['on_sale']).to be true
        end
      end

      context 'with price list applied' do
        let(:price_list) { create(:price_list, :active, store: store) }

        before do
          create(:price, variant: variant, amount: 14.99, currency: 'USD', price_list: price_list)
        end

        it 'returns price list price as the main price' do
          expect(subject['price']).to eq(14.99)
          expect(subject['display_price']).to eq('$14.99')
        end

        it 'returns base price as original_price' do
          expect(subject['original_price']).to eq(19.99)
          expect(subject['display_original_price']).to eq('$19.99')
        end

        it 'sets on_sale to true' do
          expect(subject['on_sale']).to be true
        end

        it 'includes the price_list_id' do
          expect(subject['price_list_id']).to eq(price_list.prefix_id)
        end
      end

      context 'with price list that increases price' do
        let(:price_list) { create(:price_list, :active, store: store) }

        before do
          create(:price, variant: variant, amount: 24.99, currency: 'USD', price_list: price_list)
        end

        it 'sets on_sale to false when price list price is higher' do
          expect(subject['on_sale']).to be false
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
  end
end
