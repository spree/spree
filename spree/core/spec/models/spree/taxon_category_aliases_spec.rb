require 'spec_helper'

# Covers the Taxon -> Category deprecation aliases (renamed in 6.0, removed in 6.1):
# constant aliases stay real classes (AR-safe), and every resurrected service/job,
# the taxons queue, and the method bridges warn through Spree::Deprecation.
RSpec.describe 'Taxon -> Category deprecation aliases' do
  describe 'constant aliases resolve to the canonical class' do
    it 'keeps them as true class aliases (not proxies), so is_a?/STI stay correct' do
      expect(Spree::Taxon).to equal(Spree::Category)
      expect(Spree::Classification).to equal(Spree::ProductCategory)
      expect(Spree::PromotionRuleTaxon).to equal(Spree::PromotionRuleCategory)
      expect(Spree::Promotion::Rules::Taxon).to equal(Spree::Promotion::Rules::Category)
    end
  end

  describe Spree::Taxons::AddProducts do
    it 'warns and delegates to Spree::Categories::AddProducts (adds the products)' do
      category = create(:taxon)
      product = create(:product)

      expect(Spree::Deprecation).to receive(:warn).with(/Spree::Categories::AddProducts/)
      described_class.call(taxons: [category], products: [product])

      expect(category.reload.products).to include(product)
    end
  end

  describe Spree::Taxons::RemoveProducts do
    it 'warns and delegates to Spree::Categories::RemoveProducts (removes the products)' do
      category = create(:taxon)
      product = create(:product)
      create(:product_category, category: category, product: product)

      expect(Spree::Deprecation).to receive(:warn).with(/Spree::Categories::RemoveProducts/)
      described_class.call(taxons: [category], products: [product])

      expect(category.reload.products).not_to include(product)
    end
  end

  describe Spree::Taxons::RegenerateProducts do
    it 'warns and no-ops (categories are manual in 6.0)' do
      expect(Spree::Deprecation).to receive(:warn).with(/manual/)
      result = described_class.call(taxon: double(:category))

      expect(result).to be_success
    end
  end

  describe Spree::Products::AutoMatchTaxons do
    it 'warns and delegates to the renamed AutoMatchCollections service' do
      product = create(:product)

      expect(Spree::Deprecation).to receive(:warn).with(/AutoMatchCollections/)
      result = described_class.call(product: product)

      expect(result).to be_a(Spree::ServiceModule::Result)
    end
  end

  describe Spree::Products::AutoMatchTaxonsJob do
    it 'is a subclass of the renamed job and warns on perform' do
      expect(described_class.superclass).to eq(Spree::Products::AutoMatchCollectionsJob)

      product = create(:product)
      expect(Spree::Deprecation).to receive(:warn).with(/AutoMatchCollectionsJob/)

      expect { described_class.new.perform(product.id) }.not_to raise_error
    end
  end

  describe Spree::Products::TouchTaxonsJob do
    it 'is a subclass of the renamed job and warns on perform' do
      expect(described_class.superclass).to eq(Spree::Products::TouchCategoriesJob)

      category = create(:taxon)
      expect(Spree::Deprecation).to receive(:warn).with(/TouchCategoriesJob/)

      expect { described_class.new.perform([category.id], []) }.not_to raise_error
    end
  end

  describe 'Spree.queues.taxons' do
    it 'warns and returns the categories queue' do
      expect(Spree::Deprecation).to receive(:warn).with(/Spree.queues.categories/)
      expect(Spree.queues.taxons).to eq(Spree.queues.categories)
    end
  end

  describe 'method bridges' do
    it 'Spree::Product#taxons warns and returns #categories' do
      product = create(:product)
      expect(Spree::Deprecation).to receive(:warn).with(/#categories/)
      expect(product.taxons).to eq(product.categories)
    end

    it 'Spree::Product#main_taxon warns and returns #primary_category' do
      product = create(:product)
      expect(Spree::Deprecation).to receive(:warn).with(/#primary_category/)
      expect(product.main_taxon).to eq(product.primary_category)
    end

    it 'Spree::ProductCategory#taxon warns and returns #category' do
      product_category = create(:classification)
      expect(Spree::Deprecation).to receive(:warn).with(/#category/)
      expect(product_category.taxon).to eq(product_category.category)
    end

    it 'Spree::Store#taxons warns and returns #categories' do
      store = create(:store)
      expect(Spree::Deprecation).to receive(:warn).with(/#categories/)
      expect(store.taxons).to eq(store.categories)
    end
  end
end
