require 'spec_helper'

# Anonymous controller to test Admin::BaseController authentication and audience enforcement
class Spree::Api::V3::Admin::TestController < Spree::Api::V3::Admin::BaseController
  def index
    render json: { ok: true }
  end
end

RSpec.describe Spree::Api::V3::Admin::BaseController, type: :controller do
  controller(Spree::Api::V3::Admin::TestController) do
    def index
      if current_user
        render json: { ok: true, user_id: current_user.id }
      else
        render json: { ok: true }
      end
    end
  end

  render_views

  include_context 'API v3 Admin'

  before do
    routes.draw { get 'index' => 'spree/api/v3/admin/test#index' }
  end

  describe 'secret API key authentication' do
    context 'with valid secret API key' do
      before { request.headers['X-Spree-Api-Key'] = secret_api_key.plaintext_token }

      it 'returns 200' do
        get :index

        expect(response).to have_http_status(:ok)
      end
    end

    context 'without API key' do
      it 'returns 401 unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_token')
        expect(json_response['error']['message']).to include('secret API key')
      end
    end

    context 'with invalid API key' do
      before { request.headers['X-Spree-Api-Key'] = 'sk_invalid' }

      it 'returns 401 unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_token')
      end
    end

    context 'with publishable API key instead of secret' do
      let(:publishable_key) { create(:api_key, :publishable, store: store) }

      before { request.headers['X-Spree-Api-Key'] = publishable_key.token }

      it 'returns 401 unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with revoked secret API key' do
      before do
        secret_api_key.revoke!
        request.headers['X-Spree-Api-Key'] = secret_api_key.plaintext_token
      end

      it 'returns 401 unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with secret API key from another store' do
      let(:other_store) { create(:store) }
      let(:other_secret_key) { create(:api_key, :secret, store: other_store) }

      before { request.headers['X-Spree-Api-Key'] = other_secret_key.plaintext_token }

      it 'returns 401 unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'JWT audience enforcement' do
    before { request.headers['X-Spree-Api-Key'] = secret_api_key.plaintext_token }

    context 'with admin JWT token (audience: admin_api)' do
      before { request.headers['Authorization'] = "Bearer #{admin_jwt_token}" }

      it 'authenticates successfully' do
        get :index

        expect(response).to have_http_status(:ok)
        expect(json_response['user_id']).to eq(admin_user.id)
      end
    end

    context 'with store JWT token (audience: store_api)' do
      let(:customer) { create(:user) }
      let(:store_jwt_token) { Spree::Api::V3::TestingSupport.generate_jwt(customer, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_STORE) }

      before { request.headers['Authorization'] = "Bearer #{store_jwt_token}" }

      it 'rejects the token silently (optional auth)' do
        get :index

        expect(response).to have_http_status(:ok)
        expect(json_response['user_id']).to be_nil
      end
    end

    context 'without JWT token' do
      it 'proceeds without user (optional auth)' do
        get :index

        expect(response).to have_http_status(:ok)
        expect(json_response['user_id']).to be_nil
      end
    end
  end

  describe 'API key query parameter rejection' do
    it 'does not accept API key via query parameter' do
      get :index, params: { api_key: secret_api_key.plaintext_token }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
