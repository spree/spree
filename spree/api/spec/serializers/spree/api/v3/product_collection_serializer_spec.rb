require 'spec_helper'

RSpec.describe Spree::Api::V3::ProductCollectionSerializer do
  let(:product) { create(:product) }
  let(:collection) { create(:collection) }
  let(:product_collection) { Spree::ProductCollection.create!(product: product, collection: collection) }

  subject(:payload) { described_class.new(product_collection).to_h }

  it 'names both sides of the membership by prefixed id' do
    expect(payload['product_id']).to eq(product.prefixed_id)
    expect(payload['collection_id']).to eq(collection.prefixed_id)
  end

  it 'identifies the membership itself' do
    expect(payload['id']).to eq(product_collection.prefixed_id)
    expect(payload['id']).to start_with('pcoll_')
  end
end
