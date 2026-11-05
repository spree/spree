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

    def sources
      collection.product_collections.order(:position).pluck(:product_id, :source)
    end

    it 'materializes membership from the rules as rule rows' do
      subject
      expect(sources).to eq([[matching_product.id, 'rule']])
    end

    it 'maintains the products_count counter cache' do
      subject
      expect(collection.reload.products_count).to eq(1)
    end

    it 'removes rule rows the rules no longer match' do
      create(:product_collection, :rule, collection: collection, product: other_product, position: 1)

      described_class.call(collection: collection)

      expect(collection.reload.products).to contain_exactly(matching_product)
    end

    it 'keeps hand-picked rows the rules do not match' do
      create(:product_collection, collection: collection, product: other_product, position: 1)

      described_class.call(collection: collection)

      expect(sources).to eq([[other_product.id, 'manual'], [matching_product.id, 'rule']])
    end

    it 'keeps the positions of surviving rows and closes gaps' do
      stale = create(:product)
      create(:product_collection, :rule, collection: collection, product: stale, position: 1)
      create(:product_collection, collection: collection, product: other_product, position: 2)

      described_class.call(collection: collection)

      expect(collection.product_collections.order(:position).pluck(:product_id, :position)).
        to eq([[other_product.id, 1], [matching_product.id, 2]])
    end

    it 'leaves excluded products out' do
      create(:collection_exclusion, collection: collection, product: matching_product)

      described_class.call(collection: collection)

      expect(collection.reload.products).to be_empty
    end

    it 'marks the collection automatic while it has rules' do
      collection.update_columns(automatic: false)

      expect { subject }.to change { collection.reload.automatic }.to(true)
    end

    context 'with memberships from before 6.1' do
      before do
        create(:product_collection, collection: collection, product: other_product, position: 1).update_columns(source: nil)
      end

      it 'treats them as rule rows on an automatic collection' do
        described_class.call(collection: collection)

        expect(sources).to eq([[matching_product.id, 'rule']])
      end

      it 'treats them as hand-picked on a collection that had no rules' do
        collection.update_columns(automatic: false)

        described_class.call(collection: collection)

        expect(sources).to eq([[other_product.id, 'manual'], [matching_product.id, 'rule']])
      end
    end

    context 'when the last rule is gone' do
      before do
        described_class.call(collection: collection)
        create(:product_collection, collection: collection, product: other_product, position: 2)
        rule.delete
      end

      it 'removes the rule rows, keeps the hand-picked ones and stops being automatic' do
        described_class.call(collection: collection.reload)

        expect(sources).to eq([[other_product.id, 'manual']])
        expect(collection.reload).not_to be_automatic
      end
    end
  end
end
