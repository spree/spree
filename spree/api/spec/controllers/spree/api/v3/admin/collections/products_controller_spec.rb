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
    let!(:product_a) { create(:product, store: store) }
    let!(:product_b) { create(:product, store: store) }
    let!(:product_c) { create(:product, store: store) }
    let!(:other_collection) { create(:collection, store: store) }
    let!(:other_product) { create(:product, store: store) }

    before do
      Spree::ProductCollection.create!(collection: collection, product: product_b, position: 1, source: 'manual')
      Spree::ProductCollection.create!(collection: collection, product: product_a, position: 2, source: 'manual')
      Spree::ProductCollection.create!(collection: collection, product: product_c, position: 3, source: 'manual')
      # A product in a different collection must not leak into this list.
      Spree::ProductCollection.create!(collection: other_collection, product: other_product, position: 1, source: 'manual')
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

    it 'lists the rule-materialized products of an automatic collection' do
      automatic = create(:automatic_collection, store: store)
      member = create(:product, store: store)
      Spree::ProductCollection.create!(collection: automatic, product: member, position: 1, source: 'rule')

      get :index, params: { collection_id: automatic.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |p| p['id'] }).to include(member.prefixed_id)
    end
  end

  it_behaves_like 'a product membership surface' do
    let(:parent_route_params) { { collection_id: collection.prefixed_id } }
    let(:foreign_parent_route_params) do
      { collection_id: create(:collection, store: create(:store)).prefixed_id }
    end

    def seed_member(product)
      Spree::Collections::AddProducts.call(collections: [collection], products: [product])
    end

    def member_products
      collection.products.reload.to_a
    end
  end

  describe 'collections with rules' do
    let!(:product) { create(:product, store: store) }
    let!(:ruled) { create(:automatic_collection, store: store) }

    before { create(:tag_collection_rule, collection: ruled, value: 'nothing-matches') }

    it 'hand-picks a product, marking the membership manual' do
      post :create, params: { collection_id: ruled.prefixed_id, product_ids: [product.prefixed_id] }, as: :json

      expect(response).to have_http_status(:created)
      expect(Spree::ProductCollection.find_by(collection: ruled, product: product).source).to eq('manual')
    end

    it 'turns a rule-matched membership into a hand-picked one' do
      Spree::ProductCollection.create!(collection: ruled, product: product, position: 1, source: 'rule')

      post :create, params: { collection_id: ruled.prefixed_id, product_ids: [product.prefixed_id] }, as: :json

      expect(Spree::ProductCollection.where(collection: ruled, product: product).pluck(:source)).to eq(['manual'])
    end

    it 'removes a product' do
      Spree::ProductCollection.create!(collection: ruled, product: product, position: 1, source: 'manual')

      delete :destroy, params: { collection_id: ruled.prefixed_id, product_ids: [product.prefixed_id] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(Spree::ProductCollection.where(collection: ruled, product: product)).to be_empty
    end

    it 'repositions a product' do
      other = create(:product, store: store)
      Spree::ProductCollection.create!(collection: ruled, product: product, position: 1, source: 'rule')
      Spree::ProductCollection.create!(collection: ruled, product: other, position: 2, source: 'manual')

      patch :reposition, params: { collection_id: ruled.prefixed_id, id: other.prefixed_id, new_position: 0 }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::ProductCollection.where(collection: ruled).order(:position).pluck(:product_id)).to eq([other.id, product.id])
    end
  end

  describe 'PATCH #reposition' do
    let!(:first)  { create(:product, store: store) }
    let!(:second) { create(:product, store: store) }
    let!(:third)  { create(:product, store: store) }

    before do
      Spree::ProductCollection.create!(collection: collection, product: first, position: 1, source: 'manual')
      Spree::ProductCollection.create!(collection: collection, product: second, position: 2, source: 'manual')
      Spree::ProductCollection.create!(collection: collection, product: third, position: 3, source: 'manual')
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
