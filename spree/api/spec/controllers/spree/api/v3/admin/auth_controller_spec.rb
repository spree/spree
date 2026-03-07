require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::AuthController, type: :controller do
  render_views

  include_context 'API v3 Admin'

  before do
    request.headers['X-Spree-Api-Key'] = secret_api_key.plaintext_token
  end

  describe 'POST #create (login)' do
    let!(:existing_admin) { create(:admin_user, password: 'password123', password_confirmation: 'password123') }

    it 'authenticates with email and password' do
      post :create, params: { provider: 'email', email: existing_admin.email, password: 'password123' }

      expect(response).to have_http_status(:ok)
      expect(json_response['token']).to be_present
    end

    it 'returns user data on successful login' do
      post :create, params: { provider: 'email', email: existing_admin.email, password: 'password123' }

      expect(json_response['user']).to be_present
      expect(json_response['user']['email']).to eq(existing_admin.email)
    end

    it 'returns a JWT with admin audience' do
      post :create, params: { provider: 'email', email: existing_admin.email, password: 'password123' }

      token = json_response['token']
      secret = Rails.application.secret_key_base
      payload = JWT.decode(token, secret, true, algorithm: 'HS256').first

      expect(payload['aud']).to eq('admin_api')
      expect(payload['user_type']).to eq('admin')
    end

    context 'invalid credentials' do
      it 'returns unauthorized for wrong password' do
        post :create, params: { provider: 'email', email: existing_admin.email, password: 'wrong' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_failed')
      end

      it 'returns unauthorized for non-existent email' do
        post :create, params: { provider: 'email', email: 'nonexistent@example.com', password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_failed')
      end

      it 'returns unauthorized for missing email' do
        post :create, params: { provider: 'email', password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized for missing password' do
        post :create, params: { provider: 'email', email: existing_admin.email }

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

    context 'without secret API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        post :create, params: { provider: 'email', email: existing_admin.email, password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a non-admin user' do
      let!(:regular_user) { create(:user, password: 'password123', password_confirmation: 'password123') }

      it 'returns unauthorized' do
        post :create, params: { provider: 'email', email: regular_user.email, password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_failed')
      end
    end
  end

  describe 'POST #refresh' do
    before do
      request.headers['Authorization'] = "Bearer #{admin_jwt_token}"
    end

    it 'returns a new token' do
      post :refresh

      expect(response).to have_http_status(:ok)
      expect(json_response['token']).to be_present
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
    end

    context 'without token' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        post :refresh

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end

    context 'with invalid token' do
      before { request.headers['Authorization'] = 'Bearer invalid' }

      it 'returns unauthorized' do
        post :refresh

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end

    context 'with expired token' do
      let(:expired_token) { Spree::Api::V3::TestingSupport.generate_jwt(admin_user, expiration: -1.hour.to_i, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN) }

      before { request.headers['Authorization'] = "Bearer #{expired_token}" }

      it 'returns unauthorized' do
        post :refresh

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end

    context 'with store API token (wrong audience)' do
      let(:store_token) { Spree::Api::V3::TestingSupport.generate_jwt(admin_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_STORE) }

      before { request.headers['Authorization'] = "Bearer #{store_token}" }

      it 'returns unauthorized' do
        post :refresh

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end
  end
end
