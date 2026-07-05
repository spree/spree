require 'spec_helper'

# Test JWT authentication concerns.
# Token generation tested via AuthController (login).
# Token verification/extraction tested via CustomersController (GET /customers/me requires JWT).
RSpec.describe 'Spree::Api::V3::JwtAuthentication' do
  describe 'token generation' do
    # Use AuthController for testing token generation (login creates JWT)
    let(:controller_class) { Spree::Api::V3::Store::AuthController }

    it 'includes jti, iss, and aud claims in generated token', type: :request do
      store = Spree::Store.default || create(:store)
      api_key = create(:api_key, :publishable, store: store)
      existing_user = create(:user, password: 'password123', password_confirmation: 'password123')

      post '/api/v3/store/auth/login',
           params: { provider: 'email', email: existing_user.email, password: 'password123' }.to_json,
           headers: { 'X-Spree-Api-Key' => api_key.token, 'Content-Type' => 'application/json' }

      data = JSON.parse(response.body)
      token = data['token']
      secret = Rails.application.credentials.jwt_secret_key || ENV['JWT_SECRET_KEY'] || Rails.application.secret_key_base
      payload = JWT.decode(token, secret, true, algorithm: 'HS256').first

      expect(payload['jti']).to be_present
      expect(payload['iss']).to eq('spree')
      expect(payload['aud']).to eq('store_api')
      expect(payload['user_id']).to eq(existing_user.id)
      expect(payload['user_type']).to eq('customer')
      expect(payload['exp']).to be_present
    end
  end

  describe 'token verification and extraction' do
    let!(:store) { Spree::Store.default || create(:store) }
    let!(:api_key) { create(:api_key, :publishable, store: store) }
    let!(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }
    let(:headers) { { 'X-Spree-Api-Key' => api_key.token, 'Content-Type' => 'application/json' } }

    def generate_jwt(user, expiration: 3600)
      Spree::Api::V3::TestingSupport.generate_jwt(user, expiration: expiration)
    end

    it 'extracts token from Authorization Bearer header', type: :request do
      jwt = generate_jwt(user)
      get '/api/v3/store/customers/me', headers: headers.merge('Authorization' => "Bearer #{jwt}")

      expect(response).to have_http_status(:ok)
    end

    it 'rejects tokens with wrong issuer', type: :request do
      bad_token = JWT.encode(
        { user_id: user.id, user_type: 'customer', iss: 'wrong', aud: 'store_api', exp: 1.hour.from_now.to_i },
        Rails.application.secret_key_base,
        'HS256'
      )
      get '/api/v3/store/customers/me', headers: headers.merge('Authorization' => "Bearer #{bad_token}")

      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects tokens with wrong audience', type: :request do
      bad_token = JWT.encode(
        { user_id: user.id, user_type: 'customer', iss: 'spree', aud: 'wrong_api', exp: 1.hour.from_now.to_i },
        Rails.application.secret_key_base,
        'HS256'
      )
      get '/api/v3/store/customers/me', headers: headers.merge('Authorization' => "Bearer #{bad_token}")

      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects expired tokens', type: :request do
      expired_token = generate_jwt(user, expiration: -1.hour.to_i)
      get '/api/v3/store/customers/me', headers: headers.merge('Authorization' => "Bearer #{expired_token}")

      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not extract token from query params on non-digitals controllers', type: :request do
      jwt = generate_jwt(user)
      get '/api/v3/store/customers/me', params: { token: jwt }, headers: headers

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
