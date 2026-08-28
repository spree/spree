require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::ImportsController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  let(:other_seller) { create(:seller, :approved, store: store) }

  before do
    request.headers['Authorization'] = "Bearer #{seller_jwt_token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    let!(:mine) { create(:product_import, store: store, seller: seller, user: seller_user) }
    let!(:theirs) { create(:product_import, store: store, seller: other_seller, user: seller_user) }
    let!(:operators) { create(:product_import, store: store, user: seller_user) }

    it "lists only this seller's imports" do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('id')).to contain_exactly(mine.prefixed_id)
    end
  end

  describe 'GET #show' do
    let!(:theirs) { create(:product_import, store: store, seller: other_seller, user: seller_user) }

    # 404 rather than 403: the caller cannot tell whether the id exists.
    it "404s on another seller's import" do
      get :show, params: { id: theirs.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    # Proves the catalog reaches Spree::Import: this role holds exactly
    # `write_products`, so a subject list without the import models would pass
    # the key gate and then be refused by CanCanCan.
    it 'creates an import owned by the seller' do
      post :create, params: { type: 'products' }, as: :json

      expect(response).to have_http_status(:created)
      expect(Spree::Import.last.owner).to eq(seller)
    end

    it 'refuses a type that is not a seller\'s to run' do
      post :create, params: { type: 'customers' }, as: :json

      expect(response).not_to have_http_status(:created)
      expect(Spree::Imports::Customers.count).to eq(0)
    end
  end

  describe 'GET #template' do
    it 'serves the products template' do
      get :template, params: { type: 'products' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('slug')
    end

    it '422s for a type outside the seller allowlist' do
      get :template, params: { type: 'customers' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
