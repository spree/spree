# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Password Resets API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:existing_user) { create(:user, email: 'customer@example.com', password: 'password123') }

  path '/api/v3/store/password_resets' do
    post 'Request a password reset' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description 'Sends a password reset email if an account exists for the given email address. Always returns 202 Accepted to prevent email enumeration.'

      sdk_example 'customer-password-resets/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      request_body_for

      response '202', 'password reset requested' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { email: existing_user.email } }

        schema type: :object,
               properties: {
                 message: { type: :string }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['message']).to be_present
        end
      end

      response '202', 'email not found (same response to prevent enumeration)' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { email: 'nonexistent@example.com' } }

        schema type: :object,
               properties: {
                 message: { type: :string }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['message']).to be_present
        end
      end

      response '401', 'missing API key' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:body) { { email: existing_user.email } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/password_resets/{token}' do
    patch 'Reset password with token' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description 'Resets the password using a token received via email. Returns a JWT token on success (auto-login).'

      sdk_example 'customer-password-resets/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :token, in: :path, type: :string, required: true,
                description: 'Password reset token from the email'
      request_body_for

      response '200', 'password reset successful' do
        let(:'x-spree-api-key') { api_key.token }
        let(:token) { existing_user.generate_token_for(:password_reset) }
        let(:body) { { password: 'newsecurepassword', password_confirmation: 'newsecurepassword' } }

        schema '$ref' => '#/components/schemas/AuthResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['user']).to be_present
          expect(data['user']['email']).to eq(existing_user.email)
        end
      end

      response '422', 'invalid or expired token' do
        let(:'x-spree-api-key') { api_key.token }
        let(:token) { 'invalid-token' }
        let(:body) { { password: 'newsecurepassword', password_confirmation: 'newsecurepassword' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('password_reset_token_invalid')
        end
      end

      response '422', 'password confirmation mismatch' do
        let(:'x-spree-api-key') { api_key.token }
        let(:token) { existing_user.generate_token_for(:password_reset) }
        let(:body) { { password: 'newsecurepassword', password_confirmation: 'differentpassword' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '401', 'missing API key' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:token) { 'some-token' }
        let(:body) { { password: 'newsecurepassword', password_confirmation: 'newsecurepassword' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
