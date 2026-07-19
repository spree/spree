require 'spec_helper'

module Spree
  RSpec.describe Collections::RemoveProducts do
    let(:store) { @default_store }
    let!(:collection) { create(:collection, store: store) }
    let!(:products) { create_list(:product, 3) }

    before { Spree::Collections::AddProducts.call(collections: [collection], products: products) }

    it 'removes the given products and re-packs positions' do
      described_class.call(collections: [collection], products: [products.second])

      expect(collection.reload.products).to match_array([products.first, products.third])
      expect(collection.product_collections.order(:position).pluck(:position)).to eq([1, 2])
    end

    it 'updates counter caches' do
      expect {
        described_class.call(collections: [collection], products: [products.second])
      }.to change { collection.reload.products_count }.from(3).to(2)
    end
  end
end
