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

      sdk_example <<~JS
        const auth = await client.store.auth.login({
          email: 'customer@example.com',
          password: 'password123',
        })
      JS

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

  path '/api/v3/store/auth/register' do
    post 'Register' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description 'Creates a new customer account and returns a JWT token'

      sdk_example <<~JS
        const auth = await client.store.auth.register({
          email: 'newuser@example.com',
          password: 'password123',
          first_name: 'John',
          last_name: 'Doe',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: 'email', example: 'newuser@example.com' },
          password: { type: :string, minLength: 6, example: 'password123' },
          password_confirmation: { type: :string, example: 'password123' },
          first_name: { type: :string, example: 'John' },
          last_name: { type: :string, example: 'Doe' }
        },
        required: %w[email password]
      }

      response '201', 'registration successful' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) do
          {
            email: 'newuser@example.com',
            password: 'password123',
            first_name: 'John',
            last_name: 'Doe'
          }
        end

        schema '$ref' => '#/components/schemas/AuthResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['user']).to be_present

          # Verify user was created
          new_user = Spree.user_class.find_by(email: 'newuser@example.com')
          expect(new_user).to be_present
          expect(new_user.first_name).to eq('John')
        end
      end

      response '422', 'email already taken' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) do
          {
            email: existing_user.email,
            password: 'password123'
          }
        end

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('validation_error')
        end
      end
    end
  end

  path '/api/v3/store/auth/refresh' do
    post 'Refresh token' do
      tags 'Authentication'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Generates a new JWT token for the authenticated user'

      sdk_example <<~JS
        const auth = await client.store.auth.refresh({
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true,
                description: 'Bearer token'

      response '200', 'token refreshed' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:jwt_token) { Spree::Api::V3::TestingSupport.generate_jwt(existing_user) }

        schema '$ref' => '#/components/schemas/AuthResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['user']).to be_present
        end
      end

      response '401', 'missing or invalid token' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { 'Bearer invalid_token' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
