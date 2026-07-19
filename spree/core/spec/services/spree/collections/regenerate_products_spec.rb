require 'spec_helper'

module Spree
  RSpec.describe Collections::RegenerateProducts do
    let(:store) { @default_store }
    let(:tag) { ActsAsTaggableOn::Tag.create(name: 'sale') }
    let!(:matching_product) { create(:product, tags: [tag]) }
    let!(:other_product) { create(:product) }
    let!(:collection) { create(:automatic_collection, store: store) }
    let!(:rule) { create(:tag_collection_rule, :is_equal_to, collection: collection, value: 'sale') }

    subject { described_class.call(collection: collection) }

    it 'materializes membership from the rules' do
      subject
      expect(collection.reload.products).to contain_exactly(matching_product)
    end

    it 'maintains the products_count counter cache' do
      subject
      expect(collection.reload.products_count).to eq(1)
    end

    it 'reconciles membership — wipes stale rows and rebuilds from the rules' do
      # explicit calls (not the memoized `subject`) so the service actually re-runs
      described_class.call(collection: collection)
      expect(collection.reload.products).to contain_exactly(matching_product)

      # a stale membership for a product that does not match the rules
      Spree::ProductCollection.create!(collection: collection, product: other_product)
      expect(collection.reload.products).to include(other_product)

      described_class.call(collection: collection)
      expect(collection.reload.products).to contain_exactly(matching_product)
    end

    context 'with a manual collection' do
      let!(:collection) { create(:collection, store: store) }
      let!(:rule) { nil }

      it 'is a no-op' do
        expect { subject }.not_to change { Spree::ProductCollection.count }
      end
    end
  end
end
