require 'spec_helper'

RSpec.describe Spree::Catalogs::ResolvePrices do
  let(:store) { @default_store }
  let(:product) { create(:product, store: store, price: 100) }
  let(:variant) { product.default_variant }
  let(:catalog) { create(:catalog, store: store) }

  def resolve(catalog, currency: 'USD')
    described_class.new(catalog: catalog, currency: currency).call(variant)
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

    it 'answers nothing when no price exists in the currency' do
      expect(resolve(catalog, currency: 'JPY')).to be_nil
    end

    it 'rounds a derived amount to the currency minor unit' do
      create(:price_list, :active, store: store, catalog: catalog,
                                   price_adjustment_percentage: -33.333)

      expect(resolve(catalog.reload).amount).to eq(66.67)
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
