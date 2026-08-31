require 'spec_helper'

# The price-list walk that backs Spree's own pricing. Exercised directly
# rather than through Internal#price_for so a failure names the rule that
# broke; the provider's own contract is covered in pricing_provider_spec.rb.
describe Spree::PricingProvider::Internal::Resolution do
  let(:variant) { create(:variant) }
  let(:store) { create(:store) }
  let(:currency) { 'USD' }
  let(:context) { Spree::Pricing::Context.new(variant: variant, currency: currency, store: store) }
  let(:resolver) { described_class.new(context) }

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
      let!(:price_list) { create(:price_list, :inactive, store: store) }
      let!(:list_price) { create(:price, variant: variant, currency: currency, amount: 15.99, price_list: price_list) }

      it 'falls back to base price' do
        base_price = variant.prices.base_prices.with_currency(currency).first
        price = resolver.resolve
        expect(price).to eq(base_price)
        expect(price.amount).to eq(19.99)
      end
    end

    context 'with applicable price list' do
      let!(:price_list) { create(:price_list, :active, store: store) }
      let!(:list_price) { create(:price, variant: variant, currency: currency, amount: 15.99, price_list: price_list) }

      it 'returns the price list price' do
        price = resolver.resolve
        expect(price).to eq(list_price)
        expect(price.amount).to eq(15.99)
        expect(price.price_list_id).to eq(price_list.id)
      end
    end

    context 'with a zero-amount price list price' do
      let!(:price_list) { create(:price_list, :active, store: store) }
      let!(:list_price) { create(:price, variant: variant, currency: currency, amount: 0, price_list: price_list) }

      it 'returns the free price list price instead of the base price' do
        price = resolver.resolve
        expect(price).to eq(list_price)
        expect(price.amount).to eq(0)
        expect(price.price_list_id).to eq(price_list.id)
      end

      it 'returns the free price list price when prices are already loaded' do
        variant.prices.load
        price = resolver.resolve
        expect(price).to eq(list_price)
        expect(price.amount).to eq(0)
      end
    end

    context 'with a placeholder (nil amount) price list price' do
      let!(:price_list) { create(:price_list, :active, store: store) }
      let!(:list_price) { create(:price, variant: variant, currency: currency, amount: nil, price_list: price_list) }

      it 'falls back to the base price' do
        base_price = variant.prices.base_prices.with_currency(currency).first
        price = resolver.resolve
        expect(price).to eq(base_price)
        expect(price.amount).to eq(19.99)
      end

      it 'falls back to the base price when prices are already loaded' do
        variant.prices.load
        price = resolver.resolve
        expect(price.amount).to eq(19.99)
        expect(price.price_list_id).to be_nil
      end
    end

    context 'with multiple applicable price lists' do
      let!(:second_position_list) { create(:price_list, :active, store: store, position: 2) }
      let!(:second_position_price) { create(:price, variant: variant, currency: currency, amount: 17.99, price_list: second_position_list) }

      let!(:first_position_list) { create(:price_list, :active, store: store, position: 1) }
      let!(:first_position_price) { create(:price, variant: variant, currency: currency, amount: 15.99, price_list: first_position_list) }

      it 'returns the first position price list price' do
        price = resolver.resolve
        expect(price).to eq(first_position_price)
        expect(price.amount).to eq(15.99)
        expect(price.price_list_id).to eq(first_position_list.id)
      end
    end

    context 'with date range price list' do
      let!(:price_list) do
        create(:price_list, :active,
               store: store,
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
          price = resolver.resolve
          expect(price).to eq(base_price)
        end
      end
    end

    context 'with volume-based pricing' do
      let!(:bulk_list) { create(:price_list, :active, store: store) }
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
        variant.prices.delete_all
      end

      it 'returns a new unpersisted price object' do
        price = resolver.resolve
        expect(price).to be_a(Spree::Price)
        expect(price).not_to be_persisted
        expect(price.amount).to be_nil
        expect(price.currency).to eq(currency)
      end
    end

    # A list carrying a percentage derives a price from the base price for
    # every variant it holds no explicit amount for. Such a list is always
    # catalog-owned — the assortment is what scopes the percentage to
    # products — so the buyer here is a member of the catalog's audience
    # (docs/plans/6.0-price-list-automatic-pricing.md).
    context 'with an automatic (percentage adjustment) price list' do
      let(:company) { create(:company, store: store) }
      let(:catalog) do
        create(:catalog, store: store).tap do |owner|
          create(:catalog_assignment, catalog: owner, assignable: company)
        end
      end
      let!(:price_list) do
        create(:price_list, :active, store: store, catalog: catalog, price_adjustment_percentage: -15)
      end
      let(:context) do
        Spree::Pricing::Context.new(variant: variant, currency: currency, store: store, company: company)
      end

      before { variant.prices.base_prices.with_currency(currency).update_all(amount: 20.00) }

      it 'derives the price from the base price' do
        price = resolver.resolve

        expect(price.amount).to eq(17.00)
        expect(price.price_list_id).to eq(price_list.id)
        expect(price).not_to be_persisted
      end

      it 'applies a markup for a positive percentage' do
        price_list.update!(price_adjustment_percentage: 10)

        expect(resolver.resolve.amount).to eq(22.00)
      end

      it 'tracks the base price rather than freezing a copy of it' do
        variant.prices.base_prices.with_currency(currency).update_all(amount: 40.00)

        expect(resolver.resolve.amount).to eq(34.00)
      end

      it 'rounds to the currency minor unit' do
        variant.prices.base_prices.with_currency(currency).update_all(amount: 9.99)

        # 9.99 × 0.85 = 8.4915
        expect(resolver.resolve.amount).to eq(8.49)
      end

      it 'lets an explicit row override the adjustment' do
        create(:price, variant: variant, currency: currency, amount: 12.34, price_list: price_list)

        expect(resolver.resolve.amount).to eq(12.34)
      end

      # `add_products` materializes nil-amount rows; those mean "in the list,
      # not priced", so they must not block the derived amount.
      it 'derives through a nil-amount placeholder row' do
        create(:price, variant: variant, currency: currency, amount: nil, price_list: price_list)

        expect(resolver.resolve.amount).to eq(17.00)
      end

      it 'yields nothing when the variant has no base price in this currency' do
        variant.prices.delete_all

        price = resolver.resolve
        expect(price.amount).to be_nil
        expect(price).not_to be_persisted
      end

      # A fresh resolver per assertion, because one instance memoizes the
      # base price it read — which is the point of the object, and what a
      # request-scoped resolution relies on.
      it 'leaves the compare-at alone by default' do
        variant.prices.base_prices.with_currency(currency).update_all(compare_at_amount: 30.00)

        expect(described_class.new(context).resolve.compare_at_amount).to be_nil
      end

      it 'derives the compare-at when the list says to' do
        variant.prices.base_prices.with_currency(currency).update_all(compare_at_amount: 30.00)
        price_list.update!(adjust_compare_at: true)

        expect(described_class.new(context).resolve.compare_at_amount).to eq(25.50)
      end

      it 'works the same when the variant prices are already loaded' do
        variant.prices.load

        expect(resolver.resolve.amount).to eq(17.00)
      end

      # The adjustment is a property of the list, not of a currency: it
      # applies to whatever base price the buyer's currency has.
      it 'applies to every currency the variant is priced in' do
        create(:price, variant: variant, currency: 'EUR', amount: 50.00)
        eur_context = Spree::Pricing::Context.new(
          variant: variant, currency: 'EUR', store: store, company: company
        )

        expect(described_class.new(eur_context).resolve.amount).to eq(42.50)
      end

      # An adjustment list is an ordinary owned list otherwise — its status
      # and dates gate it exactly as before.
      it 'does not apply when the list is not in effect' do
        price_list.update!(status: 'inactive')

        expect(resolver.resolve.amount).to eq(20.00)
      end

      it 'is not reached by a buyer outside the catalog audience' do
        outsider = Spree::Pricing::Context.new(variant: variant, currency: currency, store: store)

        expect(described_class.new(outsider).resolve.amount).to eq(20.00)
      end
    end

    context 'with price list from different store' do
      let(:other_store) { create(:store) }
      let!(:other_store_list) { create(:price_list, :active, store: other_store) }
      let!(:other_store_price) { create(:price, variant: variant, currency: currency, amount: 5.00, price_list: other_store_list) }

      it 'does not return price from other store price list' do
        base_price = variant.prices.base_prices.with_currency(currency).first
        price = resolver.resolve
        expect(price).to eq(base_price)
        expect(price.price_list_id).to be_nil
      end
    end
  end
end
