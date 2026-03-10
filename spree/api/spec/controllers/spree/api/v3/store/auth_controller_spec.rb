require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::AuthController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'POST #create (login)' do
    let!(:existing_user) { create(:user, password: 'password123', password_confirmation: 'password123') }

    it 'authenticates with email and password' do
      post :create, params: { provider: 'email', email: existing_user.email, password: 'password123' }

      expect(response).to have_http_status(:ok)
      expect(json_response['token']).to be_present
    end

    it 'returns user data on successful login' do
      post :create, params: { provider: 'email', email: existing_user.email, password: 'password123' }

      expect(json_response['user']).to be_present
      expect(json_response['user']['email']).to eq(existing_user.email)
    end

    context 'invalid credentials' do
      it 'returns unauthorized for wrong password' do
        post :create, params: { provider: 'email', email: existing_user.email, password: 'wrong' }

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
        post :create, params: { provider: 'email', email: existing_user.email }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        post :create, params: { provider: 'email', email: existing_user.email, password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST #refresh' do
    before do
      request.headers['Authorization'] = "Bearer #{jwt_token}"
    end

    it 'returns a new token' do
      post :refresh

      expect(response).to have_http_status(:ok)
      expect(json_response['token']).to be_present
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
      let(:expired_token) { Spree::Api::V3::TestingSupport.generate_jwt(user, expiration: -1.hour.to_i) }

      before { request.headers['Authorization'] = "Bearer #{expired_token}" }

      it 'returns unauthorized' do
        post :refresh

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end
  end
end
