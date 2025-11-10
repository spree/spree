require 'spec_helper'

describe Spree::V2::Storefront::VariantSerializer do
  subject { described_class.new(variant, params: serializer_params).serializable_hash }

  include_context 'API v2 serializers params'

  let!(:variant) { create(:variant, price: 10, compare_at_price: 15) }

  it 'returns expected attributes' do
    expect(subject[:data][:attributes]).to include(
      sku: variant.sku,
      barcode: variant.barcode,
      weight: variant.weight,
      height: variant.height,
      width: variant.width,
      depth: variant.depth,
      is_master: variant.is_master,
      options_text: variant.options_text,
      options: variant.options,
      public_metadata: variant.public_metadata,
      purchasable: variant.purchasable?,
      in_stock: variant.in_stock?,
      backorderable: variant.backorderable?,
      currency: currency,
      price: BigDecimal(10),
      display_price: '$10.00',
      compare_at_price: BigDecimal(15),
      display_compare_at_price: '$15.00'
    )
  end

  it 'returns expected relationships' do
    expect(subject[:data][:relationships]).to include(
      :product,
      :images,
      :option_values
    )
  end

  it 'returns correct type' do
    expect(subject[:data][:type]).to eq :variant
  end

  describe 'pricing context integration' do
    let(:other_store) { create(:store, default: false) }
    let(:other_zone) { create(:zone) }
    let(:user) { create(:user) }

    context 'with store-specific pricing' do
      let!(:price_list) { create(:price_list, status: 'active', priority: 100) }
      let!(:store_rule) { create(:store_price_rule, price_list: price_list, store_ids: [other_store.id]) }
      let!(:price_list_price) { create(:price, variant: variant, currency: currency, amount: 7.50, price_list: price_list) }

      context 'when store matches' do
        let(:serializer_params) do
          {
            store: other_store,
            currency: currency,
            user: nil,
            locale: locale,
            price_options: { tax_zone: zone }
          }
        end

        it 'returns the store-specific price' do
          expect(subject[:data][:attributes][:price]).to eq(BigDecimal('7.50'))
          expect(subject[:data][:attributes][:display_price]).to eq('$7.50')
        end
      end

      context 'when store does not match' do
        it 'returns the base price' do
          expect(subject[:data][:attributes][:price]).to eq(BigDecimal(10))
          expect(subject[:data][:attributes][:display_price]).to eq('$10.00')
        end
      end
    end

    context 'with zone-specific pricing' do
      let!(:price_list) { create(:price_list, status: 'active', priority: 100) }
      let!(:zone_rule) { create(:zone_price_rule, price_list: price_list, zone_ids: [other_zone.id]) }
      let!(:price_list_price) { create(:price, variant: variant, currency: currency, amount: 8.00, price_list: price_list) }

      context 'when zone matches' do
        let(:serializer_params) do
          {
            store: store,
            currency: currency,
            user: nil,
            locale: locale,
            price_options: { tax_zone: other_zone }
          }
        end

        it 'returns the zone-specific price' do
          expect(subject[:data][:attributes][:price]).to eq(BigDecimal('8.00'))
          expect(subject[:data][:attributes][:display_price]).to eq('$8.00')
        end
      end

      context 'when zone does not match' do
        it 'returns the base price' do
          expect(subject[:data][:attributes][:price]).to eq(BigDecimal(10))
          expect(subject[:data][:attributes][:display_price]).to eq('$10.00')
        end
      end
    end

    context 'with user-specific pricing' do
      let!(:price_list) { create(:price_list, status: 'active', priority: 100) }
      let!(:user_rule) { create(:user_price_rule, price_list: price_list, user_ids: [user.id]) }
      let!(:price_list_price) { create(:price, variant: variant, currency: currency, amount: 6.50, price_list: price_list) }

      context 'when user matches' do
        let(:serializer_params) do
          {
            store: store,
            currency: currency,
            user: user,
            locale: locale,
            price_options: { tax_zone: zone }
          }
        end

        it 'returns the user-specific price' do
          expect(subject[:data][:attributes][:price]).to eq(BigDecimal('6.50'))
          expect(subject[:data][:attributes][:display_price]).to eq('$6.50')
        end
      end

      context 'when user does not match' do
        it 'returns the base price' do
          expect(subject[:data][:attributes][:price]).to eq(BigDecimal(10))
          expect(subject[:data][:attributes][:display_price]).to eq('$10.00')
        end
      end
    end

    context 'with multiple price lists' do
      let!(:low_priority_list) { create(:price_list, status: 'active', priority: 50) }
      let!(:high_priority_list) { create(:price_list, status: 'active', priority: 100) }
      let!(:store_rule_low) { create(:store_price_rule, price_list: low_priority_list, store_ids: [store.id]) }
      let!(:store_rule_high) { create(:store_price_rule, price_list: high_priority_list, store_ids: [store.id]) }
      let!(:low_price) { create(:price, variant: variant, currency: currency, amount: 8.00, price_list: low_priority_list) }
      let!(:high_price) { create(:price, variant: variant, currency: currency, amount: 5.00, price_list: high_priority_list) }

      it 'returns the highest priority price' do
        expect(subject[:data][:attributes][:price]).to eq(BigDecimal('5.00'))
        expect(subject[:data][:attributes][:display_price]).to eq('$5.00')
      end
    end

    context 'with date-based pricing' do
      let!(:price_list) { create(:price_list, status: 'active', priority: 100, starts_at: 1.day.ago, ends_at: 1.day.from_now) }
      let!(:date_rule) { create(:date_range_price_rule, price_list: price_list, starts_at: 1.day.ago, ends_at: 1.day.from_now) }
      let!(:price_list_price) { create(:price, variant: variant, currency: currency, amount: 7.00, price_list: price_list) }

      it 'returns the date-specific price when within range' do
        expect(subject[:data][:attributes][:price]).to eq(BigDecimal('7.00'))
        expect(subject[:data][:attributes][:display_price]).to eq('$7.00')
      end

      context 'when outside date range' do
        let!(:price_list) { create(:price_list, status: 'active', priority: 100, starts_at: 2.days.from_now, ends_at: 3.days.from_now) }

        it 'returns the base price' do
          expect(subject[:data][:attributes][:price]).to eq(BigDecimal(10))
          expect(subject[:data][:attributes][:display_price]).to eq('$10.00')
        end
      end
    end
  end
end
