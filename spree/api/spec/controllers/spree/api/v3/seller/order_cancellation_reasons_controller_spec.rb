require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::OrderCancellationReasonsController, type: :controller do
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

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    let!(:reason) { create(:order_cancellation_reason, store: store, name: 'Out of stock') }

    it 'lists the marketplace’s reasons' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |row| row['name'] }).to include('Out of stock')
    end

    # A withdrawn reason must not be offered: a seller filing against it would
    # be using vocabulary the operator has retired.
    it 'leaves out retired reasons' do
      create(:order_cancellation_reason, store: store, name: 'Obsolete', active: false)

      get :index, as: :json

      expect(json_response['data'].map { |row| row['name'] }).not_to include('Obsolete')
    end

    it 'leaves out another store’s reasons' do
      other_store = create(:store)
      create(:order_cancellation_reason, store: other_store, name: 'Elsewhere')

      get :index, as: :json

      expect(json_response['data'].map { |row| row['name'] }).not_to include('Elsewhere')
    end
  end
end
