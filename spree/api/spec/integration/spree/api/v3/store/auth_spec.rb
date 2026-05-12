# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Authentication API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:existing_user) { create(:user, email: 'test@example.com', password: 'password123') }

  path '/api/v3/store/auth/login' do
    post 'Login' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description 'Authenticates a customer with email/password and returns a JWT token'

      sdk_example 'auth/login'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          provider: { type: :string, example: 'email', description: 'Authentication provider (default: email)' },
          email: { type: :string, format: 'email', example: 'customer@example.com' },
          password: { type: :string, example: 'password123' }
        },
        required: %w[email password]
      }

      response '200', 'login successful' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { email: existing_user.email, password: 'password123' } }

        schema '$ref' => '#/components/schemas/AuthResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['user']).to be_present
          expect(data['user']['email']).to eq(existing_user.email)
        end
      end

      response '401', 'invalid credentials' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { email: existing_user.email, password: 'wrong_password' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '401', 'user not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { email: 'nonexistent@example.com', password: 'password123' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '401', 'missing API key' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:body) { { email: existing_user.email, password: 'password123' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/auth/refresh' do
    post 'Refresh token' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description 'Exchanges a refresh token for a new access JWT and rotated refresh token. No Authorization header needed.'

      sdk_example 'auth/refresh'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          refresh_token: { type: :string, description: 'Refresh token from login response' }
        },
        required: %w[refresh_token]
      }

      response '200', 'token refreshed' do
        let(:'x-spree-api-key') { api_key.token }
        let(:refresh_token_record) { Spree::RefreshToken.create_for(existing_user) }
        let(:body) { { refresh_token: refresh_token_record.token } }

        schema '$ref' => '#/components/schemas/AuthResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['refresh_token']).to be_present
          expect(data['user']).to be_present
        end
      end

      response '401', 'missing or invalid refresh token' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { refresh_token: 'invalid_token' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/auth/logout' do
    post 'Logout' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Revokes the refresh token, effectively logging the customer out.'

      sdk_example 'auth/logout'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          refresh_token: { type: :string, description: 'Refresh token to revoke' }
        }
      }

      response '204', 'logout successful' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:refresh_token_record) { Spree::RefreshToken.create_for(existing_user) }
        let(:body) { { refresh_token: refresh_token_record.token } }

        run_test! do
          expect(Spree::RefreshToken.find_by(token: refresh_token_record.token)).to be_nil
        end
      end

      response '204', 'logout without refresh token (no-op)' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { {} }

        run_test!
      end
    end
  end
end
