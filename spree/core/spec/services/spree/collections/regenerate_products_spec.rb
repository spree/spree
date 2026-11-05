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

    def events_named(*names)
      published = []
      names.each { |name| Spree::Events.subscribe(name, async: false) { |event| published << event } }
      Spree::Events.activate!
      yield
      published
    end

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

    context 'events', events: true do
      before { Spree::Events.reset! }
      after { Spree::Events.reset! }

      it 'announces a product that newly matches' do
        newcomer = create(:product, tags: [tag])

        published = events_named('product_collection.created', 'product_collection.deleted') { subject }

        expect(published.map(&:name)).to eq(['product_collection.created'])
        expect(published.first.payload['id']).to eq(
          Spree::ProductCollection.find_by(collection_id: collection.id, product_id: newcomer.id).prefixed_id
        )
      end

      it 'says nothing when a re-run changes no membership' do
        subject

        published = events_named('product_collection.created', 'product_collection.deleted') do
          described_class.call(collection: collection)
        end

        expect(published).to be_empty
      end

      it 'announces a product that stopped matching' do
        subject
        matching_product.tag_list.remove('sale')
        matching_product.save!

        published = events_named('product_collection.created', 'product_collection.deleted') do
          described_class.call(collection: collection)
        end

        expect(published.map(&:name)).to eq(['product_collection.deleted'])
      end
    end
  end
end
