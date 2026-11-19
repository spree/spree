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

    context 'when the store was deleted after the collection was loaded' do
      let(:other_store) { create(:store) }

      # Soft-deletes the store the way Store#destroy does, before its
      # destroy_async cascade has reached the collections: the window the
      # regeneration runs in.
      def delete_store!
        other_store.update_column(:deleted_at, Time.current)
      end
      let!(:collection) { create(:automatic_collection, store: other_store) }

      it 'leaves the collection untouched instead of crashing' do
        membership = Spree::ProductCollection.create!(collection: collection, product: matching_product, position: 1)
        before_attributes = membership.reload.attributes
        loaded = Spree::Collection.find(collection.id)
        delete_store!

        expect { described_class.call(collection: loaded) }.not_to raise_error
        expect(Spree::ProductCollection.find_by(id: membership.id)&.attributes).to eq(before_attributes)
        expect(Spree::ProductCollection.where(collection_id: collection.id).count).to eq(1)
      end

      it 'matches no products' do
        loaded = Spree::Collection.find(collection.id)
        delete_store!

        expect(loaded.products_matching_rules).to be_empty
      end
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
