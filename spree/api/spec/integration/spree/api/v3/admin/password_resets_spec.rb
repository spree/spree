# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Password Resets API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:existing_admin) { create(:admin_user, email: 'admin@example.com', password: 'password123') }

  path '/api/v3/admin/auth/password_resets' do
    post 'Request password reset' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Requests a password reset email for an admin user. Always returns `202`
        whether or not the email matches an account, to prevent enumeration.

        `redirect_url` is where the emailed link should point (the reset token
        is appended as a `token` query param). It must match one of the store's
        allowed origins — otherwise it is silently ignored and the server-side
        default is used. The email is delivered by Spree itself via the
        `admin_user.password_reset_requested` event; this event is never
        forwarded to webhook endpoints.
      DESC

      admin_sdk_example 'auth/request-password-reset'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: 'email', example: 'admin@example.com' },
          redirect_url: {
            type: :string,
            example: 'https://admin.your-store.com/reset-password',
            description: 'Must match an allowed origin of the store; ignored otherwise.'
          }
        },
        required: %w[email]
      }

      response '202', 'reset requested' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { email: existing_admin.email } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['message']).to be_present
        end
      end
    end
  end

  path '/api/v3/admin/auth/password_resets/{id}' do
    patch 'Reset password' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Consumes a password reset token (the `token` query param from the
        emailed link), sets the new password, and signs the admin in: the
        response carries a JWT access token and the rotatable refresh token is
        set in an HttpOnly cookie. The token is single-use — it invalidates as
        soon as the password changes.
      DESC

      admin_sdk_example 'auth/reset-password'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, description: 'The reset token from the emailed link'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          password: { type: :string, example: 'new-password-123' },
          password_confirmation: { type: :string, example: 'new-password-123' }
        },
        required: %w[password password_confirmation]
      }

      response '200', 'password reset' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { existing_admin.generate_token_for(:password_reset) }
        let(:body) { { password: 'new-password-123', password_confirmation: 'new-password-123' } }

        schema '$ref' => '#/components/schemas/AuthResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['user']['email']).to eq(existing_admin.email)
        end
      end

      response '422', 'invalid or expired token' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'invalid-token' }
        let(:body) { { password: 'new-password-123', password_confirmation: 'new-password-123' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
