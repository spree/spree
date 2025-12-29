require 'spec_helper'

describe Spree::Pricing::Resolver do
  let(:variant) { create(:variant) }
  let(:store) { create(:store) }
  let(:currency) { 'USD' }
  let(:context) { Spree::Pricing::Context.new(variant: variant, currency: currency, store: store) }
  let(:resolver) { described_class.new(context) }

  # Clear cache before each test to avoid stale cached prices
  before do
    Rails.cache.clear
  end

  describe '#resolve' do
    context 'when no price lists exist' do
      it 'returns the base price' do
        base_price = variant.prices.base_prices.with_currency(currency).first
        price = resolver.resolve
        expect(price).to eq(base_price)
        expect(price.amount).to eq(19.99)
        expect(price.price_list_id).to be_nil
      end
    end

    context 'when no matching price list exists' do
      let!(:price_list) { create(:price_list, status: 'inactive') }
      let!(:list_price) { create(:price, variant: variant, currency: currency, amount: 15.99, price_list: price_list) }

      it 'falls back to base price' do
        base_price = variant.prices.base_prices.with_currency(currency).first
        price = resolver.resolve
        expect(price).to eq(base_price)
        expect(price.amount).to eq(19.99)
      end
    end

    context 'with applicable price list' do
      let!(:price_list) { create(:price_list, status: 'active', priority: 10) }
      let!(:list_price) { create(:price, variant: variant, currency: currency, amount: 15.99, price_list: price_list) }

      before do
        create(:store_price_rule, price_list: price_list, store_ids: [store.id])
      end

      it 'returns the price list price' do
        price = resolver.resolve
        expect(price).to eq(list_price)
        expect(price.amount).to eq(15.99)
        expect(price.price_list_id).to eq(price_list.id)
      end
    end

    context 'with multiple applicable price lists' do
      let!(:low_priority_list) { create(:price_list, status: 'active', priority: 10) }
      let!(:low_priority_price) { create(:price, variant: variant, currency: currency, amount: 17.99, price_list: low_priority_list) }

      let!(:high_priority_list) { create(:price_list, status: 'active', priority: 100) }
      let!(:high_priority_price) { create(:price, variant: variant, currency: currency, amount: 15.99, price_list: high_priority_list) }

      before do
        create(:store_price_rule, price_list: low_priority_list, store_ids: [store.id])
        create(:store_price_rule, price_list: high_priority_list, store_ids: [store.id])
      end

      it 'returns the highest priority price list price' do
        price = resolver.resolve
        expect(price).to eq(high_priority_price)
        expect(price.amount).to eq(15.99)
        expect(price.price_list_id).to eq(high_priority_list.id)
      end
    end

    context 'with date range price list' do
      let!(:price_list) do
        create(:price_list,
               status: 'active',
               starts_at: 1.day.ago,
               ends_at: 1.day.from_now)
      end
      let!(:list_price) { create(:price, variant: variant, currency: currency, amount: 15.99, price_list: price_list) }

      it 'returns price list price when within date range' do
        price = resolver.resolve
        expect(price).to eq(list_price)
      end

      it 'returns base price when outside date range' do
        base_price = variant.prices.base_prices.with_currency(currency).first
        Timecop.travel(2.days.from_now) do
          Rails.cache.clear # Clear cache for the new time context
          price = resolver.resolve
          expect(price).to eq(base_price)
        end
      end
    end

    context 'with volume-based pricing' do
      let!(:bulk_list) { create(:price_list, status: 'active', priority: 50) }
      let!(:bulk_price) { create(:price, variant: variant, currency: currency, amount: 8.00, price_list: bulk_list) }

      before do
        # Update the base price to 10.00 for this test
        variant.prices.base_prices.with_currency(currency).update_all(amount: 10.00)
        create(:volume_price_rule, price_list: bulk_list, min_quantity: 10)
      end

      it 'returns bulk price when quantity threshold met' do
        context_with_quantity = Spree::Pricing::Context.new(
          variant: variant,
          currency: currency,
          store: store,
          quantity: 10
        )
        resolver = described_class.new(context_with_quantity)
        price = resolver.resolve

        expect(price).to eq(bulk_price)
        expect(price.amount).to eq(8.00)
      end

      it 'returns base price when quantity threshold not met' do
        base_price = variant.prices.base_prices.with_currency(currency).first
        context_with_quantity = Spree::Pricing::Context.new(
          variant: variant,
          currency: currency,
          store: store,
          quantity: 5
        )
        resolver = described_class.new(context_with_quantity)
        price = resolver.resolve

        expect(price).to eq(base_price)
        expect(price.amount).to eq(10.00)
      end
    end

    context 'when no base price exists' do
      before do
        variant.prices.destroy_all
      end

      it 'returns a new unpersisted price object' do
        price = resolver.resolve
        expect(price).to be_a(Spree::Price)
        expect(price).not_to be_persisted
        expect(price.amount).to be_nil
        expect(price.currency).to eq(currency)
      end
    end
  end
end
