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

    context 'without read_product_types' do
      let(:seller_role) { create(:role, name: 'Seller', resource: seller, permissions: %w[write_products]) }

      it 'is forbidden' do
        get :index, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET #show' do
    it 'returns the type' do
      get :show, params: { id: product_type.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Apparel')
    end

    # The form warns a seller which options the type is about to add to their
    # variants. Labels, not ids: a seller manages no option-type vocabulary
    # and has no endpoint to resolve ids against, so ids alone would leave the
    # warning permanently blank.
    it 'names the option types picking it will add' do
      typed = create(:product_type_with_option_types, store: store)
      expected = typed.option_types.map { |option_type| option_type.label.presence || option_type.name }

      get :show, params: { id: typed.prefixed_id }, as: :json

      expect(json_response['option_type_labels']).to match_array(expected)
      expect(json_response['option_type_labels']).to all(be_present)
    end

    it 'answers an empty list for a type that adds no options' do
      get :show, params: { id: product_type.prefixed_id }, as: :json

      expect(json_response['option_type_labels']).to eq([])
    end

    # Filing is the operator's, so a seller is never shown a consequence they
    # cannot see the result of.
    it 'withholds the categories the type files under' do
      get :show, params: { id: product_type.prefixed_id }, as: :json

      expect(json_response).not_to include('category_ids', 'products_count', 'custom_field_definitions')
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
