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

    context 'events', events: true do
      before { Spree::Events.reset! }
      after { Spree::Events.reset! }

      it 'announces a product that newly matches' do
        subject
        newcomer = create(:product, tags: [tag])

        published = events_named('product_collection.created', 'product_collection.deleted') do
          described_class.call(collection: collection)
        end

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

    describe 'the ids of memberships that survive' do
      let!(:second_product) { create(:product, tags: [tag]) }

      it 'keeps them across a run that changes nothing' do
        subject
        before = collection.product_collections.order(:product_id).pluck(:product_id, :id)

        described_class.call(collection: collection)

        expect(collection.product_collections.order(:product_id).pluck(:product_id, :id)).to eq(before)
      end

      it 'keeps the survivor when another product drops out' do
        subject
        survivor = collection.product_collections.find_by(product_id: second_product.id)

        matching_product.tag_list.remove('sale')
        matching_product.save!
        described_class.call(collection: collection)

        expect(collection.product_collections.pluck(:id)).to eq([survivor.id])
      end

      it 'closes the gap the removal leaves in the positions' do
        subject
        matching_product.tag_list.remove('sale')
        matching_product.save!

        described_class.call(collection: collection)

        expect(collection.product_collections.order(:position).pluck(:position)).to eq([1])
      end
    end
  end
end
