require 'spec_helper'

module Spree
  RSpec.describe Collections::AddProducts do
    let(:store) { @default_store }
    let!(:collection) { create(:collection, store: store) }
    let!(:products) { create_list(:product, 2) }

    it 'adds products to the collection with sequential positions' do
      described_class.call(collections: [collection], products: products)

      expect(collection.reload.products).to match_array(products)
      expect(collection.product_collections.order(:position).pluck(:position)).to eq([1, 2])
    end

    it 'marks the rows hand-picked' do
      described_class.call(collections: [collection], products: products)

      expect(collection.product_collections.pluck(:source).uniq).to eq(['manual'])
    end

    it 'turns a rule membership into a hand-pick in place' do
      create(:product_collection, :rule, collection: collection, product: products.first, position: 1)

      described_class.call(collections: [collection], products: [products.first])

      expect(collection.product_collections.pluck(:source, :position)).to eq([['manual', 1]])
    end

    it 'lifts an exclusion, since adding is the later act' do
      create(:collection_exclusion, collection: collection, product: products.first)

      described_class.call(collections: [collection], products: [products.first])

      expect(collection.exclusions.reload).to be_empty
      expect(collection.reload.products).to include(products.first)
    end

    it 'maintains counter caches' do
      described_class.call(collections: [collection], products: products)

      expect(collection.reload.products_count).to eq(2)
      expect(products.first.reload.collections_count).to eq(1)
    end

    it 'returns early when either side is blank' do
      expect { described_class.call(collections: [], products: products) }.not_to change { Spree::ProductCollection.count }
    end
  end
end
