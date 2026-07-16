require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Collections::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:collection) { create(:collection, store: store, name: 'Summer Sale') }

  before { request.headers.merge!(headers) }

  def member_ids
    Spree::ProductCollection.where(collection_id: collection.id).order(:position).pluck(:product_id)
  end

  describe 'GET #index' do
    let!(:product_a) { create(:product, stores: [store]) }
    let!(:product_b) { create(:product, stores: [store]) }
    let!(:product_c) { create(:product, stores: [store]) }
    let!(:other_collection) { create(:collection, store: store) }
    let!(:other_product) { create(:product, stores: [store]) }

    before do
      Spree::ProductCollection.create!(collection: collection, product: product_b, position: 1)
      Spree::ProductCollection.create!(collection: collection, product: product_a, position: 2)
      Spree::ProductCollection.create!(collection: collection, product: product_c, position: 3)
      # A product in a different collection must not leak into this list.
      Spree::ProductCollection.create!(collection: other_collection, product: other_product, position: 1)
    end

    it 'lists only the collection products, ordered by membership position' do
      get :index, params: { collection_id: collection.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].map { |p| p['id'] }
      expect(ids).to eq([product_b.prefixed_id, product_a.prefixed_id, product_c.prefixed_id])
      expect(ids).not_to include(other_product.prefixed_id)
    end

    it 'returns an empty list for a collection with no products' do
      empty = create(:collection, store: store)
      get :index, params: { collection_id: empty.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to eq([])
    end

    it '404s for an automatic collection (curation is manual-only)' do
      automatic = create(:automatic_collection, store: store)
      get :index, params: { collection_id: automatic.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    let!(:product) { create(:product, stores: [store]) }

    it 'adds the product to the collection' do
      post :create, params: { collection_id: collection.prefixed_id, product_id: product.prefixed_id }, as: :json

      expect(response).to have_http_status(:created)
      expect(member_ids).to include(product.id)
    end

    it '404s for a product outside the store' do
      other = create(:product, stores: [create(:store)])
      post :create, params: { collection_id: collection.prefixed_id, product_id: other.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it '404s for an automatic collection (membership is rule-managed, not curated)' do
      automatic = create(:automatic_collection, store: store)
      post :create, params: { collection_id: automatic.prefixed_id, product_id: product.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE #destroy' do
    let!(:product) { create(:product, stores: [store]) }

    before { Spree::ProductCollection.create!(collection: collection, product: product, position: 1) }

    it 'removes the product from the collection' do
      delete :destroy, params: { collection_id: collection.prefixed_id, id: product.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(member_ids).not_to include(product.id)
    end

    it '404s for a product not in the collection' do
      stray = create(:product, stores: [store])
      delete :destroy, params: { collection_id: collection.prefixed_id, id: stray.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH #reposition' do
    let!(:first)  { create(:product, stores: [store]) }
    let!(:second) { create(:product, stores: [store]) }
    let!(:third)  { create(:product, stores: [store]) }

    before do
      Spree::ProductCollection.create!(collection: collection, product: first, position: 1)
      Spree::ProductCollection.create!(collection: collection, product: second, position: 2)
      Spree::ProductCollection.create!(collection: collection, product: third, position: 3)
    end

    it 'moves a product to the requested index' do
      patch :reposition, params: { collection_id: collection.prefixed_id, id: third.prefixed_id, new_position: 0 }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(member_ids).to eq([third.id, first.id, second.id])
    end

    it 'returns 422 for a missing new_position' do
      patch :reposition, params: { collection_id: collection.prefixed_id, id: third.prefixed_id }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
