require 'spec_helper'

module Spree
  RSpec.describe Collections::AddProducts do
    let(:store) { @default_store }
    let!(:collection) { create(:collection, store: store) }
    let!(:products) { create_list(:product, 2) }

    def events_named(name)
      published = []
      Spree::Events.subscribe(name, async: false) { |event| published << event }
      Spree::Events.activate!
      yield
      published
    end

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

    context 'events', events: true do
      before { Spree::Events.reset! }
      after { Spree::Events.reset! }

      it 'publishes product_collection.created once per new membership' do
        published = events_named('product_collection.created') do
          described_class.call(collections: [collection], products: products)
        end

        expect(published.size).to eq(products.size)
      end

      it 'says nothing about a membership that was already there' do
        described_class.call(collections: [collection], products: products)

        published = events_named('product_collection.created') do
          described_class.call(collections: [collection], products: [products.first])
        end

        expect(published).to be_empty
      end
    end
  end
end
