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

    it 'leaves a hand-picked membership alone when the rules stop matching' do
      product = create(:product)
      create(:product_collection, collection: collection, product: product)

      described_class.call(product: product)

      expect(collection.reload.products).to include(product)
    end

    it 'does not add an excluded product' do
      product = create(:product, tags: [ActsAsTaggableOn::Tag.create(name: 'sale')])
      create(:collection_exclusion, collection: collection, product: product)

      described_class.call(product: product)

      expect(collection.reload.products).not_to include(product)
    end

    it 'removes a rule row left behind by an exclusion made meanwhile' do
      product = create(:product, tags: [ActsAsTaggableOn::Tag.create(name: 'sale')])
      create(:product_collection, :rule, collection: collection, product: product)
      Spree::CollectionExclusion.insert_all([{ collection_id: collection.id, product_id: product.id,
                                               created_at: Time.current, updated_at: Time.current }])

      described_class.call(product: product)

      expect(collection.reload.products).not_to include(product)
    end

    it 'adds a matched product as a rule row at the end' do
      first = create(:product)
      create(:product_collection, collection: collection, product: first, position: 1)
      product = create(:product, tags: [ActsAsTaggableOn::Tag.create(name: 'sale')])

      described_class.call(product: product)

      expect(Spree::ProductCollection.find_by(collection: collection, product: product)).to have_attributes(source: 'rule', position: 2)
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
