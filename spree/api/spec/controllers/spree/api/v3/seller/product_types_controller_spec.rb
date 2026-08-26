require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::ProductTypesController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user, seller_role) }
  end
  let(:seller_role) do
    create(:role, name: 'Seller', resource: seller, permissions: %w[write_products read_product_types])
  end
  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
  end

  let!(:product_type) { create(:product_type, store: store, name: 'Apparel') }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    it "lists the store's types so a seller can pick one" do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('name')).to include('Apparel')
    end

    it "leaves out another store's types" do
      elsewhere = create(:product_type, store: create(:store), name: 'Elsewhere')

      get :index, as: :json

      expect(json_response['data'].pluck('id')).not_to include(elsewhere.prefixed_id)
    end
  end

  describe 'GET #show' do
    it 'carries the custom fields the seller has to fill in' do
      get :show, params: { id: product_type.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to have_key('custom_field_definitions')
    end
  end

  # Defining types is the operator's. A seller sees them to pick one; there is
  # no route here to create, edit or delete one.
  describe 'writing a type' do
    it 'is not routable' do
      expect(post: '/api/v3/seller/product_types').not_to be_routable
      expect(patch: '/api/v3/seller/product_types/pt_x').not_to be_routable
      expect(delete: '/api/v3/seller/product_types/pt_x').not_to be_routable
    end
  end
end
