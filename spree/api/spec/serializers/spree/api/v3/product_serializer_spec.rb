require 'spec_helper'

RSpec.describe Spree::Api::V3::ProductSerializer do
  let(:store) { @default_store }
  let(:product) { create(:product) }
  let(:base_params) { { store: store, currency: 'USD' } }

  describe 'store serializer' do
    subject { described_class.new(product, params: base_params).to_h }

    it 'includes standard attributes' do
      expect(subject).to include(
        'id' => product.prefixed_id,
        'name' => product.name,
        'slug' => product.slug,
        'default_variant_id' => product.default_variant.prefixed_id
      )
      expect(subject).to have_key('thumbnail_url')
      expect(subject).to have_key('price')
    end

    it 'does not include admin-only attributes' do
      expect(subject.keys).not_to include('cost_price', 'cost_currency', 'deleted_at', 'sku', 'barcode')
    end

    describe 'purchasable' do
      before { Spree::StockLevel.where(variant: product.variants).update_all(count_on_hand: 5, backorderable: false) }

      it 'is true when a variant in stock has a price' do
        expect(subject['purchasable']).to be true
      end

      it 'is false when no variant in stock has a price in the currency' do
        expect(described_class.new(product, params: base_params.merge(currency: 'EUR')).to_h['purchasable']).to be false
      end

      # The buy box still names a variant when no seller is selling.
      it 'is false when the only priced, stocked variant is from a seller who is not selling' do
        product.variants.destroy_all
        variant = create(:variant, product: product, seller: create(:seller, :suspended, store: store), price: 5)
        variant.stock_levels.update_all(count_on_hand: 5, backorderable: false)

        expect(described_class.new(product.reload, params: base_params).to_h['purchasable']).to be false
      end

      # The buy box leads with the oldest variant when none has a regular price.
      it 'is true when a variant priced only by the shopper\'s price list is in stock, though the leading one is not' do
        product.variants.destroy_all
        price_list = create(:price_list, :active, store: store)
        sold_out, in_stock = Array.new(2) { create(:variant, product: product, price: nil) }
        [sold_out, in_stock].each { |variant| create(:price, variant: variant, currency: 'USD', amount: 50, price_list: price_list) }
        sold_out.stock_levels.update_all(count_on_hand: 0, backorderable: false)
        in_stock.stock_levels.update_all(count_on_hand: 5, backorderable: false)

        result = described_class.new(product.reload, params: base_params.merge(price_list: price_list)).to_h

        expect(result['buy_box_variant_id']).to eq(sold_out.prefixed_id)
        expect(result['purchasable']).to be true
      end
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

    describe 'tags' do
      it 'returns an empty array when product has no tags' do
        expect(subject['tags']).to eq([])
      end

      it 'returns a flat array of tag names' do
        product.tag_list.add('coffee', 'espresso', 'kitchen')
        product.save!

        expect(subject['tags']).to match_array(%w[coffee espresso kitchen])
        expect(subject['tags']).to all(be_a(String))
      end
    end

    describe 'custom_fields' do
      let(:public_definition) { create(:custom_field_definition, resource_type: 'Spree::Product') }
      let(:private_definition) { create(:custom_field_definition, :admin_only, resource_type: 'Spree::Product') }
      let!(:public_custom_field) { create(:custom_field, resource: product, custom_field_definition: public_definition, value: 'public') }
      let!(:private_custom_field) { create(:custom_field, resource: product, custom_field_definition: private_definition, value: 'private') }

      it 'does not include custom_fields without expand param' do
        expect(subject).not_to have_key('custom_fields')
      end

      it 'includes only public custom fields with expand param' do
        result = described_class.new(product, params: base_params.merge(expand: ['custom_fields'])).to_h
        expect(result['custom_fields'].length).to eq(1)
        expect(result['custom_fields'].first['value']).to eq('public')
      end
    end

    # 5.5 transition: +available_on+ resolves from the current channel's
    # +ProductPublication.published_at+, falling back to the legacy
    # +Product.available_on+ column. 6.0 drops the column fallback.
    describe 'available_on' do
      let(:channel) { store.default_channel }
      let(:publication) { product.product_publications.find_by(channel: channel) }

      before { Spree::Current.channel = channel }
      after  { Spree::Current.channel = nil }

      it 'returns the publication published_at when present' do
        publication.update_columns(published_at: Time.utc(2025, 6, 15))
        expect(subject['available_on']).to eq('2025-06-15T00:00:00.000Z')
      end

      it 'falls back to Product.available_on when the publication has no published_at' do
        publication.update_columns(published_at: nil)
        product.update_columns(available_on: Time.utc(2024, 1, 1))
        expect(subject['available_on']).to eq('2024-01-01T00:00:00.000Z')
      end

      it 'returns nil when neither is set' do
        publication.update_columns(published_at: nil)
        product.update_columns(available_on: nil)
        expect(subject['available_on']).to be_nil
      end
    end
  end
end
