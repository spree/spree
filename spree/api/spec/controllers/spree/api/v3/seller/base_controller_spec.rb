require 'spec_helper'

# Anonymous controller so the branch's authentication and seller resolution can
# be exercised without depending on any particular endpoint existing yet.
class Spree::Api::V3::Seller::TestController < Spree::Api::V3::Seller::BaseController
  skip_scope_check!

  def index
    render json: { ok: true, seller_id: current_seller&.prefixed_id, store_id: current_store&.prefixed_id }
  end
end

RSpec.describe Spree::Api::V3::Seller::BaseController, type: :controller do
  controller(Spree::Api::V3::Seller::TestController) do
    skip_scope_check!

    def index
      render json: { ok: true, seller_id: current_seller&.prefixed_id, store_id: current_store&.prefixed_id }
    end
  end

  render_views

  include_context 'API v3 Seller'

  before { routes.draw { get 'index' => 'spree/api/v3/seller/test#index' } }

  describe 'a seller signing in to their own panel' do
    before { request.headers.merge!(seller_headers) }

    it 'resolves the seller and derives the store from it' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['seller_id']).to eq(seller.prefixed_id)
      expect(json_response['store_id']).to eq(store.prefixed_id)
    end
  end

  # The audience is checked at decode, before any seller is resolved, so these
  # never reach the membership lookup at all.
  describe 'tokens minted for another surface' do
    it 'refuses an admin token' do
      admin = create(:admin_user)
      token = Spree::Api::V3::TestingSupport.generate_jwt(
        admin, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN
      )
      request.headers['Authorization'] = "Bearer #{token}"
      request.headers['X-Spree-Seller-Id'] = seller.prefixed_id

      get :index

      expect(response).to have_http_status(:unauthorized)
    end

    it 'refuses a storefront token' do
      token = Spree::Api::V3::TestingSupport.generate_jwt(
        seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_STORE
      )
      request.headers['Authorization'] = "Bearer #{token}"
      request.headers['X-Spree-Seller-Id'] = seller.prefixed_id

      get :index

      expect(response).to have_http_status(:unauthorized)
    end

    it 'refuses a request with no token at all' do
      request.headers['X-Spree-Seller-Id'] = seller.prefixed_id

      get :index

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'acting as a seller the caller does not belong to' do
    let(:other_seller) { create(:seller, :approved, store: store) }

    it 'is forbidden' do
      request.headers['Authorization'] = "Bearer #{seller_jwt_token}"
      request.headers['X-Spree-Seller-Id'] = other_seller.prefixed_id

      get :index

      expect(response).to have_http_status(:forbidden)
    end

    # A seller on another store is no more reachable than one on this store —
    # the membership lookup never consults the store at all.
    it 'is forbidden across stores too' do
      foreign = create(:seller, :approved, store: create(:store))
      request.headers['Authorization'] = "Bearer #{seller_jwt_token}"
      request.headers['X-Spree-Seller-Id'] = foreign.prefixed_id

      get :index

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'naming no seller' do
    it 'is forbidden rather than falling back to a default' do
      request.headers['Authorization'] = "Bearer #{seller_jwt_token}"

      get :index

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'capability' do
    before { request.headers.merge!(seller_headers) }

    # Capability comes from the roles held on THIS seller, so the store's own
    # roles — including its admin super-role — confer nothing here.
    it 'reads the roles held on the seller, not on the store' do
      store.add_user(seller_user, Spree::Role.default_admin_role(store))

      get :index

      ability = controller.send(:current_ability)
      expect(ability.permission_keys).to eq(%w[read_products write_products])
      expect(ability.can?(:manage, :all)).to be(false)
    end
  end
end
