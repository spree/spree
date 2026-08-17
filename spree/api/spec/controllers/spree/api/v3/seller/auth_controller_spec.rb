require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::AuthController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  before do
    seller_user.update!(password: 'secret123', password_confirmation: 'secret123')
  end

  describe 'POST #create' do
    # The response serializes the signed-in user, and the registry key for that
    # is `admin_admin_user_serializer` — the shorter name resolves to nothing,
    # so every seller login used to raise before this spec existed.
    it 'signs a seller in' do
      post :create, params: { email: seller_user.email, password: 'secret123' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['token']).to be_present
      expect(json_response['user']['email']).to eq(seller_user.email)
    end

    # The panel cannot make any other request until it knows which seller to
    # name in X-Spree-Seller-Id.
    it 'returns the sellers the user may act for' do
      post :create, params: { email: seller_user.email, password: 'secret123' }, as: :json

      expect(json_response['sellers'].pluck('id')).to eq([seller.prefixed_id])
    end

    it 'refuses a store staff member who runs no seller' do
      staff = create(:admin_user, password: 'secret123', password_confirmation: 'secret123')

      post :create, params: { email: staff.email, password: 'secret123' }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
