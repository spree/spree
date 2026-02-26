require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::AuthController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'Spree::Api::V3::JwtAuthentication' do
    let!(:existing_user) { create(:user, password: 'password123', password_confirmation: 'password123') }

    describe 'JWT token claims' do
      it 'includes jti, iss, and aud claims in generated token' do
        post :create, params: { provider: 'email', email: existing_user.email, password: 'password123' }

        token = json_response['token']
        secret = Rails.application.credentials.jwt_secret_key || ENV['JWT_SECRET_KEY'] || Rails.application.secret_key_base
        payload = JWT.decode(token, secret, true, algorithm: 'HS256').first

        expect(payload['jti']).to be_present
        expect(payload['iss']).to eq('spree')
        expect(payload['aud']).to eq('store_api')
        expect(payload['user_id']).to eq(existing_user.id)
        expect(payload['user_type']).to eq('customer')
        expect(payload['exp']).to be_present
      end

      it 'generates unique jti for each token' do
        post :create, params: { provider: 'email', email: existing_user.email, password: 'password123' }
        first_jti = JWT.decode(json_response['token'], nil, false).first['jti']

        post :create, params: { provider: 'email', email: existing_user.email, password: 'password123' }
        second_jti = JWT.decode(json_response['token'], nil, false).first['jti']

        expect(first_jti).not_to eq(second_jti)
      end
    end

    describe 'token verification' do
      it 'rejects tokens with wrong issuer' do
        bad_token = JWT.encode(
          { user_id: user.id, user_type: 'customer', iss: 'wrong', aud: 'store_api', exp: 1.hour.from_now.to_i },
          Rails.application.secret_key_base,
          'HS256'
        )
        request.headers['Authorization'] = "Bearer #{bad_token}"

        post :refresh

        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects tokens with wrong audience' do
        bad_token = JWT.encode(
          { user_id: user.id, user_type: 'customer', iss: 'spree', aud: 'wrong_api', exp: 1.hour.from_now.to_i },
          Rails.application.secret_key_base,
          'HS256'
        )
        request.headers['Authorization'] = "Bearer #{bad_token}"

        post :refresh

        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects expired tokens' do
        expired_token = Spree::Api::V3::TestingSupport.generate_jwt(user, expiration: -1.hour.to_i)
        request.headers['Authorization'] = "Bearer #{expired_token}"

        post :refresh

        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe 'configurable expiration' do
      it 'uses the configured jwt_expiration' do
        original = Spree::Api::Config[:jwt_expiration]
        Spree::Api::Config[:jwt_expiration] = 7200

        post :create, params: { provider: 'email', email: existing_user.email, password: 'password123' }

        token = json_response['token']
        payload = JWT.decode(token, nil, false).first

        # Token expiration should be approximately 2 hours from now
        expected_exp = Time.current.to_i + 7200
        expect(payload['exp']).to be_within(5).of(expected_exp)
      ensure
        Spree::Api::Config[:jwt_expiration] = original
      end
    end

    describe 'token extraction' do
      it 'extracts token from Authorization Bearer header' do
        request.headers['Authorization'] = "Bearer #{jwt_token}"

        post :refresh

        expect(response).to have_http_status(:ok)
      end

      it 'does not extract token from query params on non-digitals controllers' do
        post :refresh, params: { token: jwt_token }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
