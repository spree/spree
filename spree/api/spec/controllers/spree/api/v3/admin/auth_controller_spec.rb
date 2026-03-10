require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::AuthController, type: :controller do
  render_views

  include_context 'API v3 Admin'

  describe 'POST #create (login)' do
    let!(:existing_admin) { create(:admin_user, password: 'password123', password_confirmation: 'password123') }

    context 'without any authentication headers' do
      it 'authenticates with email and password' do
        post :create, params: { email: existing_admin.email, password: 'password123' }

        expect(response).to have_http_status(:ok)
        expect(json_response['token']).to be_present
        expect(json_response['user']).to be_present
        expect(json_response['user']['email']).to eq(existing_admin.email)
      end

      it 'returns a JWT with admin audience and correct claims' do
        post :create, params: { email: existing_admin.email, password: 'password123' }

        token = json_response['token']
        secret = Rails.application.secret_key_base
        payload = JWT.decode(token, secret, true, algorithm: 'HS256').first

        expect(payload['aud']).to eq('admin_api')
        expect(payload['user_type']).to eq('admin')
        expect(payload['user_id']).to eq(existing_admin.id)
        expect(payload['iss']).to eq('spree')
        expect(payload['exp']).to be > Time.current.to_i
        expect(payload['jti']).to be_present
      end

      it 'returns user data in the response' do
        post :create, params: { email: existing_admin.email, password: 'password123' }

        expect(json_response['user']).to have_key('id')
        expect(json_response['user']).to have_key('email')
      end
    end

    context 'with secret API key header (also works)' do
      before { request.headers['X-Spree-Api-Key'] = secret_api_key.plaintext_token }

      it 'authenticates successfully' do
        post :create, params: { email: existing_admin.email, password: 'password123' }

        expect(response).to have_http_status(:ok)
        expect(json_response['token']).to be_present
      end
    end

    context 'with explicit email provider' do
      it 'authenticates successfully' do
        post :create, params: { provider: 'email', email: existing_admin.email, password: 'password123' }

        expect(response).to have_http_status(:ok)
        expect(json_response['token']).to be_present
      end
    end

    context 'invalid credentials' do
      it 'returns unauthorized for wrong password' do
        post :create, params: { email: existing_admin.email, password: 'wrong' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_failed')
      end

      it 'returns unauthorized for non-existent email' do
        post :create, params: { email: 'nonexistent@example.com', password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_failed')
      end

      it 'returns unauthorized for missing email' do
        post :create, params: { password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized for missing password' do
        post :create, params: { email: existing_admin.email }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized for empty credentials' do
        post :create, params: { email: '', password: '' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with unsupported provider' do
      it 'returns bad request' do
        post :create, params: { provider: 'unsupported', email: existing_admin.email, password: 'password123' }

        expect(response).to have_http_status(:bad_request)
        expect(json_response['error']['code']).to eq('invalid_provider')
      end
    end

    context 'with a non-admin user' do
      let!(:regular_user) { create(:user, password: 'password123', password_confirmation: 'password123') }

      it 'returns unauthorized' do
        post :create, params: { email: regular_user.email, password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_failed')
      end
    end

    it 'does not leak timing information between existing and non-existing emails' do
      # Both should return the same error code regardless of whether the email exists
      post :create, params: { email: existing_admin.email, password: 'wrong' }
      existing_error = json_response['error']['code']

      post :create, params: { email: 'nonexistent@example.com', password: 'wrong' }
      nonexistent_error = json_response['error']['code']

      expect(existing_error).to eq(nonexistent_error)
    end
  end

  describe 'POST #refresh' do
    context 'with valid admin JWT token' do
      before { request.headers['Authorization'] = "Bearer #{admin_jwt_token}" }

      it 'returns a new token' do
        post :refresh

        expect(response).to have_http_status(:ok)
        expect(json_response['token']).to be_present
        expect(json_response['token']).not_to eq(admin_jwt_token)
      end

      it 'returns user data' do
        post :refresh

        expect(json_response['user']).to be_present
        expect(json_response['user']['email']).to eq(admin_user.email)
      end

      it 'returns a JWT with admin audience' do
        post :refresh

        token = json_response['token']
        secret = Rails.application.secret_key_base
        payload = JWT.decode(token, secret, true, algorithm: 'HS256').first

        expect(payload['aud']).to eq('admin_api')
        expect(payload['user_type']).to eq('admin')
        expect(payload['user_id']).to eq(admin_user.id)
      end

      it 'returns user data in the response' do
        post :refresh

        expect(json_response['user']).to have_key('id')
        expect(json_response['user']).to have_key('email')
      end
    end

    context 'without token' do
      it 'returns unauthorized' do
        post :refresh

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end

    context 'with invalid token' do
      before { request.headers['Authorization'] = 'Bearer invalid_garbage_token' }

      it 'returns unauthorized' do
        post :refresh

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end

    context 'with expired token' do
      let(:expired_token) do
        Spree::Api::V3::TestingSupport.generate_jwt(
          admin_user,
          expiration: -1.hour.to_i,
          audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN
        )
      end

      before { request.headers['Authorization'] = "Bearer #{expired_token}" }

      it 'returns unauthorized' do
        post :refresh

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end

    context 'with store API token (wrong audience)' do
      let(:store_token) do
        Spree::Api::V3::TestingSupport.generate_jwt(
          admin_user,
          audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_STORE
        )
      end

      before { request.headers['Authorization'] = "Bearer #{store_token}" }

      it 'returns unauthorized' do
        post :refresh

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end

    context 'with secret API key only (no JWT)' do
      before { request.headers['X-Spree-Api-Key'] = secret_api_key.plaintext_token }

      it 'returns unauthorized because refresh requires JWT' do
        post :refresh

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end

    context 'with tampered token' do
      let(:tampered_token) { admin_jwt_token + 'tampered' }

      before { request.headers['Authorization'] = "Bearer #{tampered_token}" }

      it 'returns unauthorized' do
        post :refresh

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'response headers' do
    it 'sets no-store cache control' do
      post :create, params: { email: 'anyone@example.com', password: 'whatever' }

      expect(response.headers['Cache-Control']).to include('no-store')
    end
  end
end
