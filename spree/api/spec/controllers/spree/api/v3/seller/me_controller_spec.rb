require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::MeController, type: :controller do
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

  before { request.headers['Authorization'] = "Bearer #{token}" }

  # Same serializer-key bug as the login endpoint: this used to raise.
  it 'answers before a seller is chosen' do
    get :show, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response['user']['email']).to eq(seller_user.email)
    expect(json_response['sellers'].pluck('id')).to eq([seller.prefixed_id])
  end

  # Capability is per seller, so there is no meaningful answer spanning all of
  # them — the panel names one and asks again.
  it 'reports no permissions until a seller is named' do
    get :show, as: :json

    expect(json_response['permission_keys']).to eq([])
  end

  it 'reports the seeded seller permissions once one is named' do
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id

    get :show, as: :json

    expect(json_response['permission_keys']).to include('write_seller_profile', 'write_products')
  end
end
