require 'spec_helper'

RSpec.describe Spree::Api::V3::ProductCollectionSerializer do
  let(:product) { create(:product) }
  let(:collection) { create(:collection) }
  let(:product_collection) { Spree::ProductCollection.create!(product: product, collection: collection, source: 'manual') }

  subject(:payload) { described_class.new(product_collection).to_h }

  it 'names both sides of the membership by prefixed id' do
    expect(payload['product_id']).to eq(product.prefixed_id)
    expect(payload['collection_id']).to eq(collection.prefixed_id)
  end

  it 'identifies the membership itself' do
    expect(payload['id']).to eq(product_collection.prefixed_id)
    expect(payload['id']).to start_with('pcoll_')
  end

  it 'still names both sides once the collection has gone' do
    membership = product_collection
    Spree::Collection.where(id: collection.id).delete_all

    payload = described_class.new(Spree::ProductCollection.new(
                                    id: membership.id, product_id: membership.product_id, collection_id: membership.collection_id
                                  )).to_h

    expect(payload['product_id']).to eq(product.prefixed_id)
    expect(payload['collection_id']).to eq(collection.prefixed_id)
  end

  it 'leaves an id nil when the column holds nothing' do
    payload = described_class.new(Spree::ProductCollection.new).to_h

    expect(payload['product_id']).to be_nil
    expect(payload['collection_id']).to be_nil
  end
end
