require 'spec_helper'

RSpec.describe Spree::Catalogs::ResolvePrices do
  let(:store) { @default_store }
  let(:product) { create(:product, store: store, price: 100) }
  let(:variant) { product.default_variant }
  let(:catalog) { create(:catalog, store: store) }

  def resolve(catalog, currency: 'USD')
    described_class.new(catalog: catalog, currency: currency).call(variant)
  end

  def resolve_list(list, currency: 'USD')
    described_class.new(price_list: list, currency: currency).call(variant)
  end

  describe 'built from a price list' do
    it 'needs a catalog or a list' do
      expect { described_class.new(currency: 'USD') }.to raise_error(ArgumentError)
    end

    it 'reads the list as it stands, draft included' do
      list = create(:price_list, :draft, store: store)
      create(:price, variant: variant, price_list: list, amount: 60, currency: 'USD')

      price = resolve_list(list)

      expect(price.amount).to eq(60)
      expect(price.source).to eq('explicit')
    end

    it 'carries the ladder as tiers' do
      list = create(:price_list, store: store)
      create(:price, variant: variant, price_list: list, amount: 60, currency: 'USD')
      create(:price, variant: variant, price_list: list, amount: 50, currency: 'USD', min_quantity: 24)
      create(:price, variant: variant, price_list: list, amount: 45, currency: 'USD', min_quantity: 96)

      price = resolve_list(list)

      expect(price.break_count).to eq(2)
      expect(price.tiers.map { |tier| [tier.min_quantity, tier.amount] }).to eq([[24, 50], [96, 45]])
    end

    it 'falls through to base for a variant the list does not price' do
      list = create(:price_list, store: store)

      price = resolve_list(list)

      expect(price.amount).to eq(100)
      expect(price.source).to eq('base')
    end

    it 'derives from the percentage of a catalog-owned list opened as a list' do
      list = create(:price_list, :draft, store: store, catalog: catalog, price_adjustment_percentage: -15)

      price = resolve_list(list)

      expect(price.amount).to eq(85)
      expect(price.source).to eq('automatic')
    end
  end

  describe '#call' do
    it 'reads the base price when the catalog prices at base' do
      price = resolve(catalog)

      expect(price.amount).to eq(100)
      expect(price.source).to eq('base')
      expect(price).not_to be_from_agreement
    end

    it 'prefers an explicit amount on the catalog own list' do
      list = create(:price_list, :active, store: store, catalog: catalog)
      create(:price, variant: variant, price_list: list, amount: 60, currency: 'USD')

      price = resolve(catalog.reload)

      expect(price.amount).to eq(60)
      expect(price.source).to eq('explicit')
      expect(price).to be_from_agreement
    end

    it 'derives an amount from the list percentage' do
      create(:price_list, :active, store: store, catalog: catalog,
                                   price_adjustment_percentage: -15)

      price = resolve(catalog.reload)

      expect(price.amount).to eq(85)
      expect(price.source).to eq('automatic')
    end

    # The divergence the products-with-prices view exists to expose: a
    # product sitting in the assortment that the agreement never prices.
    it 'falls back to base for a variant a fixed list holds no row for' do
      create(:price_list, :active, store: store, catalog: catalog)

      price = resolve(catalog.reload)

      expect(price.amount).to eq(100)
      expect(price.source).to eq('base')
    end

    it 'lets an explicit amount beat the percentage' do
      list = create(:price_list, :active, store: store, catalog: catalog,
                                          price_adjustment_percentage: -15)
      create(:price, variant: variant, price_list: list, amount: 42, currency: 'USD')

      price = resolve(catalog.reload)

      expect(price.amount).to eq(42)
      expect(price.source).to eq('explicit')
    end

    # A placeholder row is what `add_products` materializes; it means "this
    # product is on the list", not "this product is free".
    it 'ignores a placeholder row with no amount' do
      list = create(:price_list, :active, store: store, catalog: catalog,
                                          price_adjustment_percentage: -15)
      create(:price, variant: variant, price_list: list, amount: nil, currency: 'USD')

      price = resolve(catalog.reload)

      expect(price.amount).to eq(85)
      expect(price.source).to eq('automatic')
    end

    it 'leaves a draft list out of the agreement' do
      list = create(:price_list, :draft, store: store, catalog: catalog)
      create(:price, variant: variant, price_list: list, amount: 60, currency: 'USD')

      price = resolve(catalog.reload)

      expect(price.amount).to eq(100)
      expect(price.source).to eq('base')
    end

    # A product whose only variant was soft-deleted still has to render as a
    # row; taking the whole listing down over it would be the worse failure.
    it 'answers nothing for a product with no variant to price' do
      expect(described_class.new(catalog: catalog, currency: 'USD').call(nil)).to be_nil
    end

    # The reading is what the agreement will charge, not what anyone is paying
    # today: a catalog is born inactive and priced before it goes live, so a
    # draft has to show its own prices rather than the shop's.
    it 'reports the agreement price while the catalog is still a draft' do
      draft = create(:catalog, :inactive, store: store)
      create(:price_list, :active, store: store, catalog: draft, price_adjustment_percentage: -20)

      price = described_class.new(catalog: draft.reload, currency: 'USD').call(variant)

      expect(price.amount).to eq(80)
      expect(price.source).to eq('automatic')
    end

    it 'answers nothing when no price exists in the currency' do
      expect(resolve(catalog, currency: 'JPY')).to be_nil
    end

    it 'rounds a derived amount to the currency minor unit' do
      create(:price_list, :active, store: store, catalog: catalog,
                                   price_adjustment_percentage: -33.333)

      expect(resolve(catalog.reload).amount).to eq(66.67)
    end
  end

  # The reading a merchant is shown has to be the amount a buyer on the
  # agreement is actually charged — otherwise the view is confidently wrong.
  describe 'agreement with the pricing resolver' do
    let(:company) { create(:company, store: store) }

    before { create(:catalog_assignment, catalog: catalog, assignable: company) }

    def charged_to_buyer
      context = Spree::Pricing::Context.new(
        variant: variant, currency: 'USD', store: store, company: company
      )
      Spree::PricingProvider::Internal.new.price_for(context).amount
    end

    it 'matches an explicit amount' do
      list = create(:price_list, :active, store: store, catalog: catalog)
      create(:price, variant: variant, price_list: list, amount: 60, currency: 'USD')

      expect(resolve(catalog.reload).amount).to eq(charged_to_buyer)
    end

    # A percentage list derives from base prices for every variant, whether or
    # not the list holds a row for it — so the reading follows suit.
    it 'matches a derived amount for a variant the list holds no row for' do
      create(:price_list, :active, store: store, catalog: catalog,
                                   price_adjustment_percentage: -15)

      expect(resolve(catalog.reload).amount).to eq(charged_to_buyer)
    end

    it 'matches the base price a fixed list leaves alone' do
      create(:price_list, :active, store: store, catalog: catalog)

      expect(resolve(catalog.reload).amount).to eq(charged_to_buyer)
    end

    # Quantity ladders (docs/plans/6.0-volume-pricing.md). This reading makes
    # no purchase, so it must answer for one unit — and agree with what a
    # buyer of one is actually charged.
    context 'with a quantity ladder' do
      let(:list) { create(:price_list, :active, store: store, catalog: catalog) }

      it 'reads the bottom rung and counts the ones above it' do
        create(:price, variant: variant, price_list: list, amount: 60, currency: 'USD', min_quantity: 1)
        create(:price, variant: variant, price_list: list, amount: 50, currency: 'USD', min_quantity: 24)

        price = resolve(catalog.reload)

        expect(price.amount).to eq(60)
        expect(price.amount).to eq(charged_to_buyer)
        expect(price.source).to eq('explicit')
        expect(price.break_count).to eq(1)
        expect(price).to be_tiered
      end

      # A ladder starting above one unit prices nothing for a buyer of one, so
      # reading its first rung as the agreement's price would name an amount
      # nobody is charged.
      it 'reads base when the ladder starts above one unit' do
        create(:price, variant: variant, price_list: list, amount: 50, currency: 'USD', min_quantity: 24)

        price = resolve(catalog.reload)

        expect(price.amount).to eq(charged_to_buyer)
        expect(price.source).to eq('base')
        expect(price.break_count).to eq(1)
      end

      # A laddered variant is priced by its ladder alone, so the list's
      # percentage must not be reported for it either.
      it 'does not report the percentage for a laddered variant' do
        list.update!(price_adjustment_percentage: -15)
        create(:price, variant: variant, price_list: list, amount: 50, currency: 'USD', min_quantity: 24)

        price = resolve(catalog.reload)

        expect(price.amount).to eq(charged_to_buyer)
        expect(price.source).to eq('base')
      end
    end

    context 'with quantity bands on the percentage' do
      it 'reads the quantity-1 percentage and counts the bands above it' do
        list = create(:price_list, :active, store: store, catalog: catalog,
                                            price_adjustment_percentage: -10)
        create(:price_adjustment_tier, price_list: list, min_quantity: 50, percentage: -20)

        price = resolve(catalog.reload)

        expect(price.amount).to eq(90)
        expect(price.amount).to eq(charged_to_buyer)
        expect(price.source).to eq('automatic')
        expect(price.break_count).to eq(1)
      end

      # An explicit row is the deepest rung at every quantity, so the bands
      # never apply to that variant — and the page says so rather than
      # promising tiers the buyer will not get.
      it 'counts no tiers for a variant an explicit row shadows' do
        list = create(:price_list, :active, store: store, catalog: catalog,
                                            price_adjustment_percentage: -10)
        create(:price_adjustment_tier, price_list: list, min_quantity: 50, percentage: -20)
        create(:price, variant: variant, price_list: list, amount: 12, currency: 'USD')

        price = resolve(catalog.reload)

        expect(price.amount).to eq(12)
        expect(price.source).to eq('explicit')
        expect(price.break_count).to eq(0)
        expect(price).not_to be_tiered

        deep = Spree::Pricing::Context.new(
          variant: variant, currency: 'USD', store: store, company: company, quantity: 50
        )
        expect(Spree::PricingProvider::Internal.new.price_for(deep).amount).to eq(12)
      end

      # The count alone would send a merchant to the price sheet to read three
      # figures, so the ladder itself comes back with the price
      # (docs/plans/6.0-volume-pricing.md).
      it 'carries the fixed ladder as amounts, deepest last' do
        list = create(:price_list, :active, store: store, catalog: catalog)
        create(:price, variant: variant, price_list: list, amount: 60, currency: 'USD')
        create(:price, variant: variant, price_list: list, amount: 50, currency: 'USD', min_quantity: 96)
        create(:price, variant: variant, price_list: list, amount: 55, currency: 'USD', min_quantity: 24)

        price = resolve(catalog.reload)

        expect(price.tiers.map { |tier| [tier.min_quantity, tier.amount] }).to eq([[24, 55], [96, 50]])
        expect(price.break_count).to eq(2)
      end

      # A band is a percentage, but a merchant reading an agreement wants the
      # amount it comes to — so the reading resolves it against the base price.
      it 'carries percentage bands as the amounts they resolve to' do
        list = create(:price_list, :active, store: store, catalog: catalog,
                                            price_adjustment_percentage: -10)
        create(:price_adjustment_tier, price_list: list, min_quantity: 50, percentage: -20)

        price = resolve(catalog.reload)

        expect(price.amount).to eq(90)
        expect(price.tiers.map { |tier| [tier.min_quantity, tier.amount] }).to eq([[50, 80]])
      end

      it 'carries no ladder for a variant priced at one figure' do
        create(:price_list, :active, store: store, catalog: catalog)

        expect(resolve(catalog.reload).tiers).to be_empty
      end

      # A list that only discounts from a quantity up charges base for one.
      it 'reads base for a bands-only list, with the bands counted' do
        list = create(:price_list, :active, store: store, catalog: catalog)
        create(:price_adjustment_tier, price_list: list, min_quantity: 50, percentage: -20)

        price = resolve(catalog.reload)

        expect(price.amount).to eq(charged_to_buyer)
        expect(price.source).to eq('base')
        expect(price.break_count).to eq(1)
      end
    end
  end

  describe '#preload' do
    it 'answers the same amounts from preloaded rows' do
      list = create(:price_list, :active, store: store, catalog: catalog)
      create(:price, variant: variant, price_list: list, amount: 60, currency: 'USD')

      resolver = described_class.new(catalog: catalog.reload, currency: 'USD')
      resolver.preload([variant])

      expect(resolver.call(variant).amount).to eq(60)
    end

    # Silence would be the trap: a caller who preloads a page and then asks
    # about a variant outside it must get the real answer.
    it 'still answers for a variant it was not preloaded with' do
      other = create(:product, store: store, price: 20).default_variant

      resolver = described_class.new(catalog: catalog, currency: 'USD')
      resolver.preload([variant])

      expect(resolver.call(other).amount).to eq(20)
    end
  end
end
