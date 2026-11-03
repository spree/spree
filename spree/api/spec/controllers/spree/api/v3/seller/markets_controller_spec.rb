require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::MarketsController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user, seller_role) }
  end
  let(:seller_role) { create(:role, name: 'Seller', resource: seller, permissions: %w[read_products]) }
  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
  end

  let!(:europe) { create(:market, store: store, name: 'Europe') }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    it "lists the store's markets so a seller can say where a product may be sold" do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('id')).to include(europe.prefixed_id)
    end

    it "leaves out another store's markets" do
      elsewhere = create(:market, store: create(:store))

      get :index, as: :json

      expect(json_response['data'].pluck('id')).not_to include(elsewhere.prefixed_id)
    end

    it_behaves_like 'a list without N+1 queries' do
      subject { get :index, as: :json }
    end
  end
end
