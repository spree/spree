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
