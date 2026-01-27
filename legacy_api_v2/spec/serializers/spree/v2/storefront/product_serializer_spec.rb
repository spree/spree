require 'spec_helper'

describe Spree::V2::Storefront::ProductSerializer do
  subject { described_class.new(product, params: serializer_params).serializable_hash }

  include_context 'API v2 serializers params'

  let(:product) { create(:product, price: 20) }

  context 'with tags' do
    before { product.tag_list.add('tag1', 'tag2') }

    it 'returns tags' do
      expect(subject[:data][:attributes][:tags]).to eq ['tag1', 'tag2']
    end
  end

  context 'with labels' do
    before { product.label_list.add('label1', 'label2') }

    it 'returns labels' do
      expect(subject[:data][:attributes][:labels]).to eq ['label1', 'label2']
    end
  end

  describe 'pricing attributes' do
    it 'returns base price attributes' do
      expect(subject[:data][:attributes]).to include(
        currency: currency,
        price: BigDecimal(20),
        display_price: '$20.00'
      )
    end
  end

  describe 'pricing context integration' do
    let(:other_store) { create(:store, default: false) }
    let(:other_zone) { create(:zone) }
    let(:user) { create(:user) }

    context 'with store-specific pricing' do
      let!(:price_list) { create(:price_list, :active, store: other_store) }
      let!(:price_list_price) { create(:price, variant: product.master, currency: currency, amount: 12.50, price_list: price_list) }

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
          expect(subject[:data][:attributes][:price]).to eq(BigDecimal('12.50'))
          expect(subject[:data][:attributes][:display_price]).to eq('$12.50')
        end
      end

      context 'when store does not match' do
        it 'returns the base price' do
          expect(subject[:data][:attributes][:price]).to eq(BigDecimal(20))
          expect(subject[:data][:attributes][:display_price]).to eq('$20.00')
        end
      end
    end

    context 'with zone-specific pricing' do
      let!(:price_list) { create(:price_list, :active, store: store) }
      let!(:zone_rule) { create(:zone_price_rule, price_list: price_list, zone_ids: [other_zone.id]) }
      let!(:price_list_price) { create(:price, variant: product.master, currency: currency, amount: 15.00, price_list: price_list) }

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
          expect(subject[:data][:attributes][:price]).to eq(BigDecimal('15.00'))
          expect(subject[:data][:attributes][:display_price]).to eq('$15.00')
        end
      end

      context 'when zone does not match' do
        it 'returns the base price' do
          expect(subject[:data][:attributes][:price]).to eq(BigDecimal(20))
          expect(subject[:data][:attributes][:display_price]).to eq('$20.00')
        end
      end
    end

    context 'with user-specific pricing' do
      let!(:price_list) { create(:price_list, :active, store: store) }
      let!(:user_rule) { create(:user_price_rule, price_list: price_list, user_ids: [user.id]) }
      let!(:price_list_price) { create(:price, variant: product.master, currency: currency, amount: 14.00, price_list: price_list) }

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
          expect(subject[:data][:attributes][:price]).to eq(BigDecimal('14.00'))
          expect(subject[:data][:attributes][:display_price]).to eq('$14.00')
        end
      end

      context 'when user does not match' do
        it 'returns the base price' do
          expect(subject[:data][:attributes][:price]).to eq(BigDecimal(20))
          expect(subject[:data][:attributes][:display_price]).to eq('$20.00')
        end
      end
    end

    context 'with combined rules (zone AND user)' do
      let!(:price_list) { create(:price_list, :active, store: store, match_policy: 'all') }
      let!(:zone_rule) { create(:zone_price_rule, price_list: price_list, zone_ids: [other_zone.id]) }
      let!(:user_rule) { create(:user_price_rule, price_list: price_list, user_ids: [user.id]) }
      let!(:price_list_price) { create(:price, variant: product.master, currency: currency, amount: 9.00, price_list: price_list) }

      context 'when both zone and user match' do
        let(:serializer_params) do
          {
            store: store,
            currency: currency,
            user: user,
            locale: locale,
            price_options: { tax_zone: other_zone }
          }
        end

        it 'returns the combined rule price' do
          expect(subject[:data][:attributes][:price]).to eq(BigDecimal('9.00'))
          expect(subject[:data][:attributes][:display_price]).to eq('$9.00')
        end
      end

      context 'when only zone matches' do
        let(:serializer_params) do
          {
            store: store,
            currency: currency,
            user: nil,
            locale: locale,
            price_options: { tax_zone: other_zone }
          }
        end

        it 'returns the base price because both rules must match' do
          expect(subject[:data][:attributes][:price]).to eq(BigDecimal(20))
          expect(subject[:data][:attributes][:display_price]).to eq('$20.00')
        end
      end
    end

    context 'with multiple price lists' do
      let!(:second_position_list) { create(:price_list, :active, store: store, position: 2) }
      let!(:first_position_list) { create(:price_list, :active, store: store, position: 1) }
      let!(:second_price) { create(:price, variant: product.master, currency: currency, amount: 16.00, price_list: second_position_list) }
      let!(:first_price) { create(:price, variant: product.master, currency: currency, amount: 10.00, price_list: first_position_list) }

      it 'returns the first position price' do
        expect(subject[:data][:attributes][:price]).to eq(BigDecimal('10.00'))
        expect(subject[:data][:attributes][:display_price]).to eq('$10.00')
      end
    end
  end
end
