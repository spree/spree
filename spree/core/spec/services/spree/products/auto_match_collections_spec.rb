require 'spec_helper'

module Spree
  RSpec.describe Products::AutoMatchCollections do
    let(:store) { @default_store }
    let!(:collection) { create(:automatic_collection, store: store) }
    let!(:rule) { create(:tag_collection_rule, :is_equal_to, collection: collection, value: 'sale') }

    it 'adds a product that newly matches an automatic collection' do
      product = create(:product)
      expect(collection.reload.products).not_to include(product)

      product.tag_list.add('sale')
      product.save!
      described_class.call(product: product)

      expect(collection.reload.products).to include(product)
    end

    it 'removes a product that no longer matches' do
      product = create(:product, tags: [ActsAsTaggableOn::Tag.create(name: 'sale')])
      described_class.call(product: product)
      expect(collection.reload.products).to include(product)

      product.tag_list.remove('sale')
      product.save!
      described_class.call(product: product)

      expect(collection.reload.products).not_to include(product)
    end
  end
end
