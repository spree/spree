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

    # The headline case: a percentage plus a VolumeRule is an automatic
    # volume discount, with no rows to maintain
    # (docs/plans/6.0-price-list-automatic-pricing.md).
    context 'with an automatic price list carrying a contextual rule' do
      let(:company) { create(:company, store: store) }
      let(:catalog) do
        create(:catalog, store: store).tap do |owner|
          create(:catalog_assignment, catalog: owner, assignable: company)
        end
      end
      let!(:price_list) do
        create(:price_list, :active, store: store, catalog: catalog, price_adjustment_percentage: -10)
      end

      before do
        variant.prices.base_prices.with_currency(currency).update_all(amount: 20.00)
        create(:volume_price_rule, price_list: price_list, min_quantity: 10)
      end

      def price_at(quantity)
        described_class.new(
          Spree::Pricing::Context.new(
            variant: variant, currency: currency, store: store,
            company: company, quantity: quantity
          )
        ).resolve
      end

      it 'derives the adjusted price once the quantity threshold is met' do
        price = price_at(10)

        expect(price.amount).to eq(18.00)
        expect(price.price_list_id).to eq(price_list.id)
      end

      it 'leaves the base price alone below the threshold' do
        price = price_at(5)

        expect(price.amount).to eq(20.00)
        expect(price.price_list_id).to be_nil
      end

      # Rules need a quantity to judge; a catalogue listing has none, and
      # must not be priced as though it were a bulk order.
      it 'leaves the base price alone when the context carries no quantity' do
        expect(price_at(nil).amount).to eq(20.00)
      end

      # An audience rule on an owned list is inert: the catalog assignment
      # already answered that question, and re-asking it here would let a
      # stale rule switch off a price the agreement grants.
      it 'ignores an audience rule the buyer does not satisfy' do
        create(:customer_group_price_rule, price_list: price_list,
                                          customer_group_ids: [create(:customer_group, store: store).id])

        expect(price_at(10).amount).to eq(18.00)
      end

      # An explicit row is a deliberate override and beats the derived
      # amount, but only once the rule lets the list apply at all.
      it 'still prefers an explicit row over the derived amount' do
        create(:price, variant: variant, currency: currency, amount: 15.00, price_list: price_list)

        expect(price_at(10).amount).to eq(15.00)
        expect(price_at(5).amount).to eq(20.00)
      end
    end

    # Fixed contracted ladders: a variant's rows on one list, each carrying
    # the quantity from which it applies (docs/plans/6.0-volume-pricing.md).
    context 'with a quantity break ladder on a price list' do
      let!(:price_list) { create(:price_list, :active, store: store) }

      before do
        variant.prices.base_prices.with_currency(currency).update_all(amount: 20.00)
        create(:price, variant: variant, currency: currency, amount: 10.00, price_list: price_list, min_quantity: 1)
        create(:price, variant: variant, currency: currency, amount: 9.00, price_list: price_list, min_quantity: 24)
        create(:price, variant: variant, currency: currency, amount: 8.00, price_list: price_list, min_quantity: 96)
      end

      def price_at(quantity)
        described_class.new(
          Spree::Pricing::Context.new(variant: variant, currency: currency, store: store, quantity: quantity)
        ).resolve
      end

      it 'charges the deepest break the line reaches' do
        expect(price_at(1).amount).to eq(10.00)
        expect(price_at(23).amount).to eq(10.00)
        expect(price_at(24).amount).to eq(9.00)
        expect(price_at(95).amount).to eq(9.00)
        expect(price_at(96).amount).to eq(8.00)
        expect(price_at(1_000).amount).to eq(8.00)
      end

      # A listing, an export or a report asks what one unit costs and must
      # read the bottom rung rather than the deepest.
      it 'reads the bottom rung when the context carries no quantity' do
        expect(price_at(nil).amount).to eq(10.00)
      end

      it 'stamps the list on the rung it charged' do
        price = price_at(96)

        expect(price.price_list_id).to eq(price_list.id)
        expect(price.min_quantity).to eq(96)
      end

      # The walk runs off the association when a caller preloaded it, so both
      # branches have to pick the same rung.
      it 'picks the same rung from a preloaded association' do
        variant.prices.load

        expect(described_class.new(
          Spree::Pricing::Context.new(variant: variant, currency: currency, store: store, quantity: 96)
        ).resolve.amount).to eq(8.00)
      end

      # A ladder that starts above one unit prices nothing below its first
      # rung; the walk moves on exactly as it would for a variant the list
      # never priced.
      context 'when the ladder starts above one unit' do
        before { variant.prices.where(price_list: price_list, min_quantity: 1).delete_all }

        it 'falls through to the base price below the first rung' do
          price = price_at(5)

          expect(price.amount).to eq(20.00)
          expect(price.price_list_id).to be_nil
        end

        it 'still charges the ladder from its first rung up' do
          expect(price_at(24).amount).to eq(9.00)
        end
      end

      # A placeholder is skipped per row, so it cannot hide a real amount
      # standing at a lower rung.
      context 'with a placeholder at the deepest rung' do
        before { variant.prices.where(price_list: price_list, min_quantity: 96).update_all(amount: nil) }

        it 'falls back to the rung below rather than to the base price' do
          expect(price_at(120).amount).to eq(9.00)
        end
      end
    end

    # A negotiated ladder is the agreement for that variant; the list's
    # percentage, written for everything else, must not undercut it
    # (docs/plans/6.0-volume-pricing.md).
    context 'with a break ladder on an automatic price list' do
      let(:company) { create(:company, store: store) }
      let(:catalog) do
        create(:catalog, store: store).tap do |owner|
          create(:catalog_assignment, catalog: owner, assignable: company)
        end
      end
      let!(:price_list) do
        create(:price_list, :active, store: store, catalog: catalog, price_adjustment_percentage: -10)
      end

      before do
        variant.prices.base_prices.with_currency(currency).update_all(amount: 20.00)
        create(:price, variant: variant, currency: currency, amount: 9.00, price_list: price_list, min_quantity: 24)
      end

      def price_at(quantity)
        described_class.new(
          Spree::Pricing::Context.new(
            variant: variant, currency: currency, store: store, company: company, quantity: quantity
          )
        ).resolve
      end

      it 'charges the ladder rather than the percentage once a rung is reached' do
        expect(price_at(24).amount).to eq(9.00)
      end

      it 'refuses the percentage below the ladder and falls through to base' do
        price = price_at(5)

        expect(price.amount).to eq(20.00)
        expect(price.price_list_id).to be_nil
      end

      # Only the laddered variant is exempt: everything else on the list is
      # still priced by the percentage.
      it 'still applies the percentage to a variant with no ladder' do
        other = create(:variant)
        other.prices.base_prices.with_currency(currency).update_all(amount: 50.00)

        price = described_class.new(
          Spree::Pricing::Context.new(
            variant: other, currency: currency, store: store, company: company, quantity: 1
          )
        ).resolve

        expect(price.amount).to eq(45.00)
      end
    end

    # Percentage ladders: bands on the list's own adjustment
    # (docs/plans/6.0-volume-pricing.md).
    context 'with quantity bands on an automatic price list' do
      let(:company) { create(:company, store: store) }
      let(:catalog) do
        create(:catalog, store: store).tap do |owner|
          create(:catalog_assignment, catalog: owner, assignable: company)
        end
      end
      let!(:price_list) do
        create(:price_list, :active, store: store, catalog: catalog, price_adjustment_percentage: -5)
      end

      before do
        variant.prices.base_prices.with_currency(currency).update_all(amount: 100.00)
        create(:price_adjustment_tier, price_list: price_list, min_quantity: 10, percentage: -10)
        create(:price_adjustment_tier, price_list: price_list, min_quantity: 50, percentage: -20)
      end

      def price_at(quantity)
        described_class.new(
          Spree::Pricing::Context.new(
            variant: variant, currency: currency, store: store, company: company, quantity: quantity
          )
        ).resolve
      end

      it 'applies the deepest band the line reaches' do
        expect(price_at(1).amount).to eq(95.00)
        expect(price_at(9).amount).to eq(95.00)
        expect(price_at(10).amount).to eq(90.00)
        expect(price_at(49).amount).to eq(90.00)
        expect(price_at(50).amount).to eq(80.00)
      end

      # Every band is a percentage off the base price, never off the band
      # below it — otherwise "20% from fifty" would quietly mean 24%.
      it 'takes each band off the base price rather than compounding' do
        expect(price_at(50).amount).to eq(80.00)
      end

      it 'falls back to the column when the line reaches no band' do
        expect(price_at(1).amount).to eq(95.00)
      end

      it 'reads the column when the context carries no quantity' do
        expect(price_at(nil).amount).to eq(95.00)
      end

      # A signed row is what someone agreed to; a band is what the list does
      # to everything else.
      it 'still prefers an explicit row over every band' do
        create(:price, variant: variant, currency: currency, amount: 42.00, price_list: price_list)

        expect(price_at(50).amount).to eq(42.00)
      end

      # A list whose discount only starts at a quantity has no quantity-1
      # percentage at all.
      context 'when the list carries bands but no percentage of its own' do
        before { price_list.update!(price_adjustment_percentage: nil) }

        it 'charges the base price below the first band' do
          price = price_at(5)

          expect(price.amount).to eq(100.00)
          expect(price.price_list_id).to be_nil
        end

        it 'applies the band once the line reaches it' do
          expect(price_at(10).amount).to eq(90.00)
        end
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
