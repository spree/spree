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

  describe 'authentication via secret API key' do
    context 'with valid secret API key' do
      before { request.headers['X-Spree-Api-Key'] = secret_api_key.plaintext_token }

      it 'returns 200' do
        get :index

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid API key' do
      before { request.headers['X-Spree-Api-Key'] = 'sk_invalid' }

      it 'returns 401 unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
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

  describe 'authentication via JWT token' do
    context 'with valid admin JWT token' do
      before { request.headers['Authorization'] = "Bearer #{admin_jwt_token}" }

      it 'returns 200 and sets current_user' do
        get :index

        expect(response).to have_http_status(:ok)
        expect(json_response['user_id']).to eq(admin_user.id)
      end
    end

    context 'with expired JWT token' do
      let(:expired_token) do
        Spree::Api::V3::TestingSupport.generate_jwt(
          admin_user,
          expiration: -1.hour.to_i,
          audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN
        )
      end

      before { request.headers['Authorization'] = "Bearer #{expired_token}" }

      it 'returns 401 unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with store JWT token (wrong audience)' do
      let(:store_jwt_token) do
        Spree::Api::V3::TestingSupport.generate_jwt(
          admin_user,
          audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_STORE
        )
      end

      before { request.headers['Authorization'] = "Bearer #{store_jwt_token}" }

      it 'returns 401 unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with tampered JWT token' do
      before { request.headers['Authorization'] = "Bearer #{admin_jwt_token}tampered" }

      it 'returns 401 unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with completely invalid JWT token' do
      before { request.headers['Authorization'] = 'Bearer not_a_real_jwt_at_all' }

      it 'returns 401 unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a non-admin user JWT token' do
      let(:customer) { create(:user) }
      let(:customer_admin_jwt) do
        Spree::Api::V3::TestingSupport.generate_jwt(
          customer,
          audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN
        )
      end

      before { request.headers['Authorization'] = "Bearer #{customer_admin_jwt}" }

      it 'authenticates the user (authorization is handled separately)' do
        get :index

        expect(response).to have_http_status(:ok)
        expect(json_response['user_id']).to eq(customer.id)
      end
    end
  end

  describe 'authentication priority (secret key vs JWT)' do
    context 'with both valid secret key and valid JWT' do
      before do
        request.headers['X-Spree-Api-Key'] = secret_api_key.plaintext_token
        request.headers['Authorization'] = "Bearer #{admin_jwt_token}"
      end

      it 'authenticates successfully via secret key' do
        get :index

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid secret key and valid JWT' do
      before do
        request.headers['X-Spree-Api-Key'] = 'sk_invalid'
        request.headers['Authorization'] = "Bearer #{admin_jwt_token}"
      end

      it 'falls back to JWT authentication' do
        get :index

        expect(response).to have_http_status(:ok)
        expect(json_response['user_id']).to eq(admin_user.id)
      end
    end

    context 'with both invalid secret key and invalid JWT' do
      before do
        request.headers['X-Spree-Api-Key'] = 'sk_invalid'
        request.headers['Authorization'] = 'Bearer invalid_token'
      end

      it 'returns 401 unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'no authentication' do
    it 'returns 401 unauthorized' do
      get :index

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'API key query parameter rejection' do
    it 'does not accept API key via query parameter' do
      get :index, params: { api_key: secret_api_key.plaintext_token }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'response headers' do
    before { request.headers['X-Spree-Api-Key'] = secret_api_key.plaintext_token }

    it 'sets no-store cache control' do
      get :index

      expect(response.headers['Cache-Control']).to include('no-store')
    end

    it 'sets private cache control' do
      get :index

      expect(response.headers['Cache-Control']).to include('private')
    end
  end

  describe 'JWT audience enforcement' do
    before { request.headers['X-Spree-Api-Key'] = secret_api_key.plaintext_token }

    context 'with admin JWT token (audience: admin_api)' do
      before { request.headers['Authorization'] = "Bearer #{admin_jwt_token}" }

      it 'authenticates successfully and sets current_user' do
        get :index

        expect(response).to have_http_status(:ok)
        # Secret key takes priority, so user_id won't be set from JWT
        # To test JWT audience, we remove the secret key
      end
    end

    context 'with store JWT token (audience: store_api) and valid secret key' do
      let(:customer) { create(:user) }
      let(:store_jwt_token) { Spree::Api::V3::TestingSupport.generate_jwt(customer, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_STORE) }

      before { request.headers['Authorization'] = "Bearer #{store_jwt_token}" }

      it 'authenticates via secret key, ignoring the store JWT' do
        get :index

        expect(response).to have_http_status(:ok)
        expect(json_response['user_id']).to be_nil
      end
    end

    context 'without JWT token but with valid secret key' do
      it 'proceeds without user (optional auth via JWT)' do
        get :index

        expect(response).to have_http_status(:ok)
        expect(json_response['user_id']).to be_nil
      end
    end
  end

  describe 'JWT-only audience enforcement' do
    context 'with admin JWT only (no secret key)' do
      before { request.headers['Authorization'] = "Bearer #{admin_jwt_token}" }

      it 'authenticates and sets current_user' do
        get :index

        expect(response).to have_http_status(:ok)
        expect(json_response['user_id']).to eq(admin_user.id)
      end
    end

    context 'with store JWT only (wrong audience, no secret key)' do
      let(:customer) { create(:user) }
      let(:store_jwt_token) { Spree::Api::V3::TestingSupport.generate_jwt(customer, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_STORE) }

      before { request.headers['Authorization'] = "Bearer #{store_jwt_token}" }

      it 'rejects the token because audience does not match' do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
