require 'spec_helper'

module Spree
  RSpec.describe Products::AutoMatchCollections do
    let(:store) { @default_store }
    let!(:collection) { create(:automatic_collection, store: store) }
    let!(:rule) { create(:tag_collection_rule, :is_equal_to, collection: collection, value: 'sale') }

    def events_named(*names)
      published = []
      names.each { |name| Spree::Events.subscribe(name, async: false) { |event| published << event } }
      Spree::Events.activate!
      yield
      published
    end

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

    context 'events', events: true do
      before { Spree::Events.reset! }
      after { Spree::Events.reset! }

      it 'announces a membership it adds and one it removes' do
        product = create(:product)
        product.tag_list.add('sale')
        product.save!

        added = events_named('product_collection.created') { described_class.call(product: product) }
        expect(added.size).to eq(1)

        product.tag_list.remove('sale')
        product.save!

        removed = events_named('product_collection.deleted') { described_class.call(product: product) }
        expect(removed.size).to eq(1)
      end

      it 'says nothing when nothing matched differently' do
        product = create(:product)

        expect(events_named('product_collection.created', 'product_collection.deleted') do
          described_class.call(product: product)
        end).to be_empty
      end
    end
  end
end
