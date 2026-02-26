# Helper module for generating JWT tokens in tests
module Spree
  module Api
    module V3
      module TestingSupport
        def self.generate_jwt(user, expiration: 1.hour.to_i, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_STORE)
          user_type = user.is_a?(Spree.admin_user_class) ? 'admin' : 'customer'
          payload = {
            user_id: user.id,
            user_type: user_type,
            jti: SecureRandom.uuid,
            iss: Spree::Api::V3::JwtAuthentication::JWT_ISSUER,
            aud: audience,
            exp: Time.current.to_i + expiration
          }
          secret = Rails.application.credentials.jwt_secret_key || ENV['JWT_SECRET_KEY'] || Rails.application.secret_key_base
          JWT.encode(payload, secret, 'HS256')
        end
      end
    end
  end
end

shared_context 'API v3 Store' do
  let(:store) { @default_store || create(:store, default: true) }
  let(:api_key) { create(:api_key, :publishable, store: store) }
  let(:api_key_headers) { { 'x-spree-api-key' => api_key.token } }

  let(:user) { create(:user_with_addresses) }
  let(:jwt_token) { Spree::Api::V3::TestingSupport.generate_jwt(user) }
  let(:bearer_headers) { api_key_headers.merge('Authorization' => "Bearer #{jwt_token}") }

  before do
    allow_any_instance_of(Spree::Api::V3::BaseController).to receive(:current_store).and_return(store)
  end
end

shared_context 'API v3 Store authenticated' do
  include_context 'API v3 Store'

  let(:headers) { bearer_headers }
end

shared_context 'API v3 Store guest' do
  include_context 'API v3 Store'

  let(:headers) { api_key_headers }
end

# Shared examples for common response patterns
shared_examples 'returns 200 OK' do
  it 'returns 200 status' do
    subject
    expect(response).to have_http_status(:ok)
  end
end

shared_examples 'returns 201 Created' do
  it 'returns 201 status' do
    subject
    expect(response).to have_http_status(:created)
  end
end

shared_examples 'returns 204 No Content' do
  it 'returns 204 status' do
    subject
    expect(response).to have_http_status(:no_content)
  end
end

shared_examples 'returns 401 Unauthorized' do
  it 'returns 401 status' do
    subject
    expect(response).to have_http_status(:unauthorized)
  end
end

shared_examples 'returns 403 Forbidden' do
  it 'returns 403 status' do
    subject
    expect(response).to have_http_status(:forbidden)
  end
end

shared_examples 'returns 404 Not Found' do
  it 'returns 404 status' do
    subject
    expect(response).to have_http_status(:not_found)
  end
end

shared_examples 'returns 422 Unprocessable Entity' do
  it 'returns 422 status' do
    subject
    expect(response).to have_http_status(:unprocessable_content)
  end
end

shared_examples 'requires API key' do
  context 'without API key' do
    let(:headers) { {} }

    it 'returns 401 unauthorized' do
      subject
      expect(response).to have_http_status(:unauthorized)
      expect(json_response[:error]).to include('API key')
    end
  end
end

shared_examples 'requires authentication' do
  context 'without JWT token' do
    let(:headers) { api_key_headers }

    it 'returns 401 unauthorized' do
      subject
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
