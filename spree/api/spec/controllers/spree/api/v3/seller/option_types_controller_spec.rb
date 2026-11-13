require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::OptionTypesController, type: :controller do
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

  let!(:size) { create(:option_type, name: 'size', label: 'Size', store: store) }
  let!(:small) { create(:option_value, name: 'small', label: 'Small', option_type: size) }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    it "lists the store's option types" do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('name')).to include('size')
    end

    it 'expands the values to choose from' do
      get :index, params: { expand: 'option_values' }, as: :json

      entry = json_response['data'].find { |option_type| option_type['name'] == 'size' }
      expect(entry['option_values'].pluck('name')).to include('small')
    end

    it "leaves out another store's option types" do
      elsewhere = create(:option_type, name: 'elsewhere', store: create(:store))

      get :index, as: :json

      expect(json_response['data'].pluck('id')).not_to include(elsewhere.prefixed_id)
    end

    context 'without read access to products' do
      let(:seller_user) do
        create(:admin_user, :without_admin_role).tap do |user|
          seller.add_user(user, create(:role, name: 'Nothing', resource: seller, permissions: %w[read_orders]))
        end
      end

      it 'is forbidden' do
        get :index, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET #show' do
    it 'returns the option type' do
      get :show, params: { id: size.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('size')
    end
  end

  describe 'writing an option type' do
    it 'is not routable' do
      expect(post: '/api/v3/seller/option_types').not_to be_routable
      expect(patch: '/api/v3/seller/option_types/ot_x').not_to be_routable
      expect(delete: '/api/v3/seller/option_types/ot_x').not_to be_routable
    end
  end
end
