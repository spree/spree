require 'spec_helper'

RSpec.describe Spree::ProductCollection, 'lifecycle events', events: true do
  include ActiveJob::TestHelper

  let(:store) { @default_store }
  let(:product) { create(:product, store: store) }
  let!(:first) { create(:collection, store: store, automatic: false) }
  let!(:second) { create(:collection, store: store, automatic: false) }

  before { Spree::Events.reset! }
  after { Spree::Events.reset! }

  def deleted_events
    published = []
    Spree::Events.subscribe('product_collection.deleted', async: false) { |event| published << event }
    Spree::Events.activate!
    yield
    published
  end

  describe 'removal through collection_ids=' do
    before { product.update!(collection_ids: [first.id, second.id]) }

    it 'announces a collection dropped by replacing the list' do
      published = deleted_events { product.update!(collection_ids: [first.id]) }

      expect(published.size).to eq(1)
      expect(product.reload.collection_ids).to eq([first.id])
    end

    it 'announces every collection dropped by clearing the list' do
      published = deleted_events { product.update!(collection_ids: []) }

      expect(published.size).to eq(2)
      expect(product.reload.collection_ids).to be_empty
    end

    it 'unlinks the collections rather than deleting them' do
      product.update!(collection_ids: [])

      expect(Spree::Collection.where(id: [first.id, second.id]).count).to eq(2)
    end
  end
end
