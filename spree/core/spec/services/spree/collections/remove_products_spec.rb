require 'spec_helper'

module Spree
  RSpec.describe Collections::RemoveProducts do
    let(:store) { @default_store }
    let!(:collection) { create(:collection, store: store) }
    let!(:products) { create_list(:product, 3) }

    def events_named(name)
      published = []
      Spree::Events.subscribe(name, async: false) { |event| published << event }
      Spree::Events.activate!
      yield
      published
    end

    before { Spree::Collections::AddProducts.call(collections: [collection], products: products) }

    it 'regenerates a collection with rules, so products its rules match come back' do
      create(:tag_collection_rule, collection: collection, value: 'sale')

      expect { described_class.call(collections: [collection], products: [products.second]) }.
        to have_enqueued_job(Spree::Collections::RegenerateProductsJob).with(collection.id)
    end

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

    context 'events', events: true do
      before { Spree::Events.reset! }
      after { Spree::Events.reset! }

      it 'publishes product_collection.deleted once per membership removed' do
        Spree::Collections::AddProducts.call(collections: [collection], products: products)

        published = events_named('product_collection.deleted') do
          described_class.call(collections: [collection], products: products)
        end

        expect(published.size).to eq(products.size)
      end

      it 'says nothing about a product that was in none of the collections' do
        outsider = create(:product)

        published = events_named('product_collection.deleted') do
          described_class.call(collections: [collection], products: [outsider])
        end

        expect(published).to be_empty
      end
    end
  end
end
