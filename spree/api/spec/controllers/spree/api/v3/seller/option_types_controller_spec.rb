require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::OptionTypesController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
  end

  let!(:option_type) { create(:option_type, store: store, name: 'size', label: 'Size') }
  let!(:small) { create(:option_value, option_type: option_type, name: 'small', label: 'Small', position: 1) }
  let!(:large) { create(:option_value, option_type: option_type, name: 'large', label: 'Large', position: 2) }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    it "lists the store's option types with their values so a seller can build variants" do
      get :index, params: { expand: 'option_values' }, as: :json

      expect(response).to have_http_status(:ok)
      size = json_response['data'].find { |row| row['id'] == option_type.prefixed_id }
      expect(size['label']).to eq('Size')
      expect(size['option_values'].pluck('label')).to eq(%w[Small Large])
    end

    it "leaves out another store's option types" do
      elsewhere = create(:option_type, store: create(:store), name: 'elsewhere')

      get :index, as: :json

      expect(json_response['data'].pluck('id')).not_to include(elsewhere.prefixed_id)
    end

    # How the operator maintains the vocabulary is not a seller's to read.
    it 'withholds what the operator keeps to maintain the option type' do
      get :index, as: :json

      expect(json_response['data'].first).not_to include('metadata', 'filterable', 'created_at', 'updated_at')
    end

    it_behaves_like 'a list without N+1 queries' do
      subject { get :index, params: { expand: 'option_values' }, as: :json }

      let!(:records) do
        create_list(:option_type, 2, store: store).each { |type| create_list(:option_value, 2, option_type: type) }
      end
    end

    # The list exists for the product form, so it opens with the key that
    # reads products.
    context 'without read_products' do
      let(:seller_role) { create(:role, name: 'Seller', resource: seller, permissions: %w[read_orders]) }

      it 'is forbidden' do
        get :index, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'without a token' do
      let(:token) { nil }

      it 'is unauthorized' do
        request.headers['Authorization'] = nil

        get :index, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    it 'returns the option type with its values' do
      get :show, params: { id: option_type.prefixed_id, expand: 'option_values' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('size')
      expect(json_response['option_values'].pluck('id')).to eq([small.prefixed_id, large.prefixed_id])
    end

    it "404s on another store's option type" do
      elsewhere = create(:option_type, store: create(:store), name: 'elsewhere')

      get :show, params: { id: elsewhere.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  # The vocabulary is the operator's. A seller builds variants from it; there
  # is no route here to add, edit or delete an option type or its values.
  describe 'writing an option type' do
    it 'is not routable' do
      expect(post: '/api/v3/seller/option_types').not_to be_routable
      expect(patch: '/api/v3/seller/option_types/opt_x').not_to be_routable
      expect(delete: '/api/v3/seller/option_types/opt_x').not_to be_routable
    end
  end
end
