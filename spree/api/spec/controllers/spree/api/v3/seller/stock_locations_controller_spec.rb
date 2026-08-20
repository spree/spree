require 'spec_helper'

# A stock location is an address a shopper is given for returns, so the
# isolation here matters more than on most collections: the operator's
# warehouse address is not a seller's to read.
RSpec.describe Spree::Api::V3::Seller::StockLocationsController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end
  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
  end

  let!(:mine) do
    seller.stock_locations.create!(store: store, name: 'My Warehouse', default: true,
                                   address1: '1 Seller Way', city: 'London', country_code: 'GB')
  end
  let(:other_seller) { create(:seller, :approved, store: store) }
  let!(:theirs) do
    other_seller.stock_locations.create!(store: store, name: 'Their Warehouse')
  end
  let!(:first_party) { create(:stock_location, store: store, name: 'Marketplace Warehouse') }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    it "lists only this seller's locations" do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      names = json_response['data'].pluck('name')
      expect(names).to include('My Warehouse')
      expect(names).not_to include('Their Warehouse', 'Marketplace Warehouse')
    end
  end

  describe 'GET #show' do
    it 'finds its own' do
      get :show, params: { id: mine.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('My Warehouse')
    end

    # 404 rather than 403: the caller must not learn whether it exists.
    it "404s on another seller's" do
      get :show, params: { id: theirs.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "404s on the operator's own" do
      get :show, params: { id: first_party.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'creates one owned by this seller' do
      post :create, params: { name: 'Second Warehouse', city: 'Leeds', country_code: 'GB' }, as: :json

      expect(response).to have_http_status(:created)
      created = Spree::StockLocation.find_by(name: 'Second Warehouse')
      expect(created.seller).to eq(seller)
      expect(created.store).to eq(store)
    end

    # The payload does not get to say whose it is.
    it 'ignores a seller_id in the payload' do
      post :create, params: { name: 'Third Warehouse', seller_id: other_seller.prefixed_id }, as: :json

      expect(Spree::StockLocation.find_by(name: 'Third Warehouse').seller).to eq(seller)
    end
  end

  describe 'PATCH #update' do
    it 'updates its own' do
      patch :update, params: { id: mine.prefixed_id, city: 'Manchester' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload.city).to eq('Manchester')
    end

    it "404s on another seller's" do
      patch :update, params: { id: theirs.prefixed_id, city: 'Manchester' }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload.city).not_to eq('Manchester')
    end
  end

  # A location holds stock levels and is named on historical fulfillments, so
  # retiring one is deactivation rather than deletion.
  describe 'DELETE #destroy' do
    it 'is not routable' do
      expect { delete :destroy, params: { id: mine.prefixed_id }, as: :json }.
        to raise_error(ActionController::UrlGenerationError)
    end
  end
end
