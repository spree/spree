require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::DeliveryProfilesController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
  end

  let!(:profile) { create(:delivery_profile, store: store, name: 'Oversized') }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    it "lists the store's profiles so a seller can pick one" do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('name')).to include('Oversized')
      expect(json_response['data'].first.keys).to contain_exactly('id', 'name', 'default')
    end

    it "leaves out another store's profiles" do
      elsewhere = create(:delivery_profile, store: create(:store), name: 'Elsewhere')

      get :index, as: :json

      expect(json_response['data'].pluck('id')).not_to include(elsewhere.prefixed_id)
    end

    # The list exists for the product form, so it opens with the key that
    # reads products — never the operator's settings key.
    context 'without read_products' do
      let(:seller_role) { create(:role, name: 'Seller', resource: seller, permissions: %w[read_orders]) }

      it 'is forbidden' do
        get :index, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # A seller assigns a profile and never defines one.
  describe 'anything but listing' do
    it 'is not routable' do
      expect(get: '/api/v3/seller/delivery_profiles/dp_x').not_to be_routable
      expect(post: '/api/v3/seller/delivery_profiles').not_to be_routable
      expect(patch: '/api/v3/seller/delivery_profiles/dp_x').not_to be_routable
      expect(delete: '/api/v3/seller/delivery_profiles/dp_x').not_to be_routable
    end
  end
end
