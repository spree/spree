require 'spec_helper'

# What a seller may file a product under. Read only by design: the marketplace
# owns its taxonomy (docs/plans/6.0-seller-product-submission.md).
RSpec.describe Spree::Api::V3::Seller::CategoriesController, type: :controller do
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

  let!(:category) { create(:category, store: store, name: 'Lighting') }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  it "lists the store's categories" do
    get :index, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response['data'].pluck('name')).to include('Lighting')
  end

  it "leaves out another store's categories" do
    elsewhere = create(:category, store: create(:store), name: 'Elsewhere')

    get :index, as: :json

    expect(json_response['data'].pluck('id')).not_to include(elsewhere.prefixed_id)
  end

  it 'offers no way to create, edit or delete one' do
    expect(post: '/api/v3/seller/categories').not_to be_routable
    expect(patch: '/api/v3/seller/categories/cat_x').not_to be_routable
    expect(delete: '/api/v3/seller/categories/cat_x').not_to be_routable
  end
end
