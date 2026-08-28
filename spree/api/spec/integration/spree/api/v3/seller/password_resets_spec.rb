# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Password Resets API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  path '/api/v3/seller/auth/password_resets' do
    post 'Request password reset' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      description <<~DESC
        Requests a password reset email for a seller.

        Unauthenticated. Always answers `202`, whether or not the address
        belongs to a seller, so this cannot be used to discover which accounts
        exist. A store staff member who runs no seller is treated as no match:
        they have no seller panel to be sent to.

        `redirect_url` is where the emailed link should point, with the reset
        token appended as a `token` query param. It is honoured only when it
        matches one of the store's allowed origins; otherwise it is silently
        ignored and the server resolves the seller panel origin itself. The
        email is delivered by Spree via the
        `seller_user.password_reset_requested` event, which is never forwarded
        to webhook endpoints.
      DESC

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: 'email', example: 'seller@acme.test' },
          redirect_url: {
            type: :string,
            example: 'https://sellers.your-store.com/reset-password',
            description: 'Must match an allowed origin of the store; ignored otherwise.'
          }
        },
        required: %w[email]
      }

      response '202', 'reset requested' do
        let(:body) { { email: seller_user.email } }

        run_test! do |response|
          expect(JSON.parse(response.body)['message']).to be_present
        end
      end
    end
  end

  path '/api/v3/seller/auth/password_resets/{id}' do
    patch 'Reset password' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      description <<~DESC
        Spends a password reset token (the `token` query param from the emailed
        link), sets the new password and signs the seller in: the response
        carries a seller JWT and the rotatable refresh token is set in an
        HttpOnly cookie, so they land in the panel rather than on a login form.

        The token is single-use, and resetting revokes every other session the
        account holds. A token whose seller membership has since been revoked is
        refused exactly as an expired one.
      DESC

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
        let(:id) { seller_user.generate_token_for(:password_reset) }
        let(:body) { { password: 'new-password-123', password_confirmation: 'new-password-123' } }

        schema '$ref' => '#/components/schemas/AuthResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['user']['email']).to eq(seller_user.email)
        end
      end

      response '422', 'invalid or expired token' do
        let(:id) { 'invalid-token' }
        let(:body) { { password: 'new-password-123', password_confirmation: 'new-password-123' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
