require 'spec_helper'

RSpec.describe Spree::ProductCollection, type: :model do
  let(:store) { @default_store }
  let(:collection) { create(:collection, store: store) }
  let(:product) { create(:product, store: store) }

  describe 'uniqueness' do
    it 'cannot link the same product to the same collection twice' do
      create(:product_collection, collection: collection, product: product)

      expect {
        create(:product_collection, collection: collection, product: product)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'counter caches' do
    it 'maintains products_count on the collection' do
      expect {
        create(:product_collection, collection: collection, product: product)
      }.to change { collection.reload.products_count }.from(0).to(1)
    end

    it 'maintains collections_count on the product' do
      expect {
        create(:product_collection, collection: collection, product: product)
      }.to change { product.reload.collections_count }.from(0).to(1)
    end

    it 'decrements both counters on destroy' do
      product_collection = create(:product_collection, collection: collection, product: product)

      expect { product_collection.destroy }.to change { collection.reload.products_count }.from(1).to(0).
        and change { product.reload.collections_count }.from(1).to(0)
    end
  end
end
