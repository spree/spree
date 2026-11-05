require 'spec_helper'

RSpec.describe Spree::ProductCategory, 'lifecycle events', events: true do
  include ActiveJob::TestHelper

  let(:other_store) { create(:store) }
  let(:product) { create(:product, store: other_store) }
  let(:category) { create(:category, store: other_store) }

  before do
    Spree::Events.reset!
    expect(other_store.id).not_to eq(Spree::Store.default.id)
  end

  after { Spree::Events.reset! }

  def deleted_events
    published = []
    Spree::Events.subscribe('product_category.deleted', async: false) { |event| published << event }
    Spree::Events.activate!
    yield
    published
  end

  # The row has no store of its own, and `dependent: :destroy_async` runs the
  # cascade in a job with no store context — where Spree::Current.store falls
  # back to the default store. Attributed there, the deletion reaches the
  # default store's webhook endpoints and never the owning store's.
  it 'attributes a cascade delete to the store that owns the membership' do
    described_class.create!(product: product, category: category)
    Spree::Current.store = nil

    published = deleted_events { perform_enqueued_jobs { category.destroy } }

    expect(published.map(&:store_id)).to eq([other_store.id])
  end

  it 'attributes a direct delete to the owning store too' do
    membership = described_class.create!(product: product, category: category)
    Spree::Current.store = nil

    published = deleted_events { membership.destroy }

    expect(published.map(&:store_id)).to eq([other_store.id])
  end

  it 'attributes a collection membership deleted by the product going away' do
    collection = create(:collection, store: other_store)
    Spree::ProductCollection.create!(product: product, collection: collection)
    Spree::Current.store = nil

    published = []
    Spree::Events.subscribe('product_collection.deleted', async: false) { |event| published << event }
    Spree::Events.activate!
    perform_enqueued_jobs { product.destroy }

    expect(published.map(&:store_id)).to eq([other_store.id])
  end
end
