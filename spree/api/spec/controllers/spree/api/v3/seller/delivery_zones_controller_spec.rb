require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::DeliveryZonesController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  let(:seller_role) { create(:role, name: 'Seller', resource: seller, permissions: %w[read_delivery_methods]) }

  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
  end

  let(:profile) { create(:delivery_profile, store: store, name: 'Parcel') }
  let!(:zone) { create(:delivery_zone, store: store, delivery_profile: profile, name: 'Domestic') }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    it "lists the marketplace's zones so a seller can narrow a method" do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('name')).to include('Domestic')
    end

    it "leaves out another store's zones" do
      elsewhere = create(:delivery_zone, store: create(:store), name: 'Elsewhere')

      get :index, as: :json

      expect(json_response['data'].pluck('id')).not_to include(elsewhere.prefixed_id)
    end

    # A zone only means something under its profile, so the picker asks for
    # one profile's zones.
    it 'narrows to one delivery profile when asked' do
      other_profile = create(:delivery_profile, store: store, name: 'Pallet')
      other_zone = create(:delivery_zone, store: store, delivery_profile: other_profile, name: 'Freight')

      get :index, params: { delivery_profile_id: profile.prefixed_id }, as: :json

      ids = json_response['data'].pluck('id')
      expect(ids).to include(zone.prefixed_id)
      expect(ids).not_to include(other_zone.prefixed_id)
    end

    # The filter is a plain parameter, not a Ransack predicate — a client that
    # wraps it into `q[...]` gets the unfiltered list back, which is what made
    # the panel's picker offer every zone in the store.
    it 'ignores a Ransack-wrapped profile filter rather than pretending to narrow' do
      other_profile = create(:delivery_profile, store: store, name: 'Pallet')
      other_zone = create(:delivery_zone, store: store, delivery_profile: other_profile, name: 'Freight')

      get :index, params: { q: { delivery_profile_id: profile.prefixed_id } }, as: :json

      expect(json_response['data'].pluck('id')).to include(zone.prefixed_id, other_zone.prefixed_id)
    end

    it "404s on another store's delivery profile" do
      elsewhere = create(:delivery_profile, store: create(:store))

      get :index, params: { delivery_profile_id: elsewhere.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    context 'without read_delivery_methods' do
      let(:seller_role) { create(:role, name: 'Seller', resource: seller, permissions: %w[read_orders]) }

      it 'is forbidden' do
        get :index, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # Where the marketplace ships is its own decision.
  describe 'anything but listing' do
    it 'is not routable' do
      expect(get: '/api/v3/seller/delivery_zones/dz_x').not_to be_routable
      expect(post: '/api/v3/seller/delivery_zones').not_to be_routable
      expect(patch: '/api/v3/seller/delivery_zones/dz_x').not_to be_routable
      expect(delete: '/api/v3/seller/delivery_zones/dz_x').not_to be_routable
    end
  end
end
