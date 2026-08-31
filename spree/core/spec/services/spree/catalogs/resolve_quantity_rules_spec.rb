require 'spec_helper'

RSpec.describe Spree::Catalogs::ResolveQuantityRules do
  let(:store) { @default_store }
  let(:product) { create(:product, store: store) }
  let(:variant) { product.default_variant }

  describe '#call' do
    it 'falls back to the variant base rules when no catalog applies' do
      variant.update!(minimum_order_quantity: 12, order_multiple: 6)

      rule = described_class.new([]).call(variant)

      expect(rule.minimum).to eq(12)
      expect(rule.multiple).to eq(6)
    end

    it "reads a catalog's own default columns" do
      catalog = create(:catalog, store: store, minimum_order_quantity: 48, order_multiple: 24)

      rule = described_class.new([catalog]).call(variant)

      expect(rule.minimum).to eq(48)
      expect(rule.multiple).to eq(24)
    end

    it 'lets a per-variant override beat the catalog default' do
      catalog = create(:catalog, store: store, minimum_order_quantity: 48, order_multiple: 24)
      create(:catalog_quantity_rule, catalog: catalog, variant: variant,
                                     minimum_order_quantity: 480, order_multiple: 240)

      rule = described_class.new([catalog]).call(variant)

      expect(rule.minimum).to eq(480)
      expect(rule.multiple).to eq(240)
    end

    it 'leaves a variant the override does not name on the catalog default' do
      catalog = create(:catalog, store: store, minimum_order_quantity: 48, order_multiple: 24)
      other = create(:variant, product: create(:product, store: store))
      create(:catalog_quantity_rule, catalog: catalog, variant: other,
                                     minimum_order_quantity: 480, order_multiple: 240)

      rule = described_class.new([catalog]).call(variant)

      expect(rule.minimum).to eq(48)
    end

    # The per-field rule: an agreement silent on a field passes it through
    # rather than waiving it.
    describe 'per-field resolution' do
      it 'takes each field from the nearest catalog that states it' do
        nearest = create(:catalog, store: store, minimum_order_quantity: 100, order_multiple: nil)
        fallback = create(:catalog, store: store, minimum_order_quantity: 48, order_multiple: 24)

        rule = described_class.new([nearest, fallback]).call(variant)

        expect(rule.minimum).to eq(100)
        expect(rule.multiple).to eq(24)
      end

      it 'falls through a catalog that states nothing at all' do
        silent = create(:catalog, store: store)
        fallback = create(:catalog, store: store, minimum_order_quantity: 48, order_multiple: 24)

        rule = described_class.new([silent, fallback]).call(variant)

        expect(rule.minimum).to eq(48)
        expect(rule.multiple).to eq(24)
      end

      it 'reaches the variant base for a field no catalog states' do
        variant.update!(order_multiple: 6)
        catalog = create(:catalog, store: store, minimum_order_quantity: 48)

        rule = described_class.new([catalog]).call(variant)

        expect(rule.minimum).to eq(48)
        expect(rule.multiple).to eq(6)
      end

      it "mixes an override field with the same catalog's default for the other" do
        catalog = create(:catalog, store: store, minimum_order_quantity: 48, order_multiple: 24)
        create(:catalog_quantity_rule, catalog: catalog, variant: variant,
                                       minimum_order_quantity: 100, order_multiple: nil)

        rule = described_class.new([catalog]).call(variant)

        expect(rule.minimum).to eq(100)
        expect(rule.multiple).to eq(24)
      end

      it 'mixes an override field with a further catalog for the other field' do
        nearest = create(:catalog, store: store)
        create(:catalog_quantity_rule, catalog: nearest, variant: variant,
                                       minimum_order_quantity: 12, order_multiple: nil)
        fallback = create(:catalog, store: store, minimum_order_quantity: 48, order_multiple: 24)

        rule = described_class.new([nearest, fallback]).call(variant)

        expect(rule.minimum).to eq(12)
        expect(rule.multiple).to eq(24)
      end
    end
  end

  describe '#order_minimum' do
    let(:catalog) { create(:catalog, store: store) }

    it 'finds the row for the currency asked about' do
      create(:catalog_order_minimum, catalog: catalog, currency: 'USD', amount: 500)
      create(:catalog_order_minimum, catalog: catalog, currency: 'EUR', amount: 450)

      expect(described_class.new([catalog]).order_minimum('USD').amount).to eq(500)
      expect(described_class.new([catalog]).order_minimum('EUR').amount).to eq(450)
    end

    it 'is nil for a currency no catalog states' do
      create(:catalog_order_minimum, catalog: catalog, currency: 'USD', amount: 500)

      expect(described_class.new([catalog]).order_minimum('GBP')).to be_nil
    end

    # A nearer agreement silent on a currency must not waive the fallback's
    # threshold — the same per-field rule the quantity terms follow.
    it 'falls through a nearer catalog that prices a different currency' do
      nearest = create(:catalog, store: store)
      create(:catalog_order_minimum, catalog: nearest, currency: 'EUR', amount: 450)
      fallback = create(:catalog, store: store)
      create(:catalog_order_minimum, catalog: fallback, currency: 'USD', amount: 500)

      expect(described_class.new([nearest, fallback]).order_minimum('USD').amount).to eq(500)
    end

    it 'lets the nearest catalog win a currency both state' do
      nearest = create(:catalog, store: store)
      create(:catalog_order_minimum, catalog: nearest, currency: 'USD', amount: 250)
      fallback = create(:catalog, store: store)
      create(:catalog_order_minimum, catalog: fallback, currency: 'USD', amount: 500)

      expect(described_class.new([nearest, fallback]).order_minimum('USD').amount).to eq(250)
    end
  end

  describe '#blank?' do
    it 'is true when no catalog states any term' do
      expect(described_class.new([create(:catalog, store: store)])).to be_blank
    end

    it 'is false once a catalog carries terms' do
      catalog = create(:catalog, store: store, minimum_order_quantity: 48)

      expect(described_class.new([catalog])).not_to be_blank
    end
  end
end
