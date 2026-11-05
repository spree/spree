require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Collections::ExclusionsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:collection) { create(:collection, store: store) }
  let!(:product) { create(:product, store: store) }
  let(:other_store) { create(:store) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    let!(:exclusion) { create(:collection_exclusion, collection: collection, product: product) }

    it 'lists the excluded products' do
      get :index, params: { collection_id: collection.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].first).to include('id' => exclusion.prefixed_id, 'product_id' => product.prefixed_id)
    end

    it_behaves_like 'a list without N+1 queries' do
      subject { get :index, params: { collection_id: collection.prefixed_id, expand: 'product' }, as: :json }

      let!(:more_exclusions) do
        create_list(:product, 2, store: store).map { |excluded| create(:collection_exclusion, collection: collection, product: excluded) }
      end
    end

    it "returns not found for another store's collection" do
      get :index, params: { collection_id: create(:collection, store: other_store).prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    before { Spree::Collections::AddProducts.call(collections: [collection], products: [product]) }

    it 'excludes the product and removes it from the collection' do
      post :create, params: { collection_id: collection.prefixed_id, product_id: product.prefixed_id }, as: :json

      expect(response).to have_http_status(:created)
      expect(collection.exclusions.reload.map(&:product)).to eq([product])
      expect(collection.products.reload).to be_empty
    end

    it "returns not found for another store's product" do
      foreign = create(:product, store: other_store)

      post :create, params: { collection_id: collection.prefixed_id, product_id: foreign.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(collection.exclusions.reload).to be_empty
    end

    it 'refuses excluding the same product twice' do
      create(:collection_exclusion, collection: collection, product: product)

      post :create, params: { collection_id: collection.prefixed_id, product_id: product.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'DELETE #destroy' do
    let!(:exclusion) { create(:collection_exclusion, collection: collection, product: product) }

    it 'lifts the exclusion' do
      delete :destroy, params: { collection_id: collection.prefixed_id, id: exclusion.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(collection.exclusions.reload).to be_empty
    end
  end
end
