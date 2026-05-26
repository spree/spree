# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Authentication API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:existing_admin) { create(:admin_user, email: 'admin@example.com', password: 'password123') }

  path '/api/v3/admin/auth/login' do
    post 'Login' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Authenticates an admin user and returns a short-lived JWT access token.
        The rotatable refresh token is set in an HttpOnly cookie — it is not
        included in the response body.

        Dispatches by the `provider` field to a strategy registered in
        `Spree.admin_authentication_strategies`. When `provider` is omitted it
        defaults to `email`, which uses the built-in email/password strategy.

        To plug in a third-party identity provider (Okta, Azure AD, Google
        Workspace SSO, a custom JWT issuer, SAML, etc.), register a
        `Spree::Authentication::Strategies::BaseStrategy` subclass under a
        provider key, then send `{ "provider": "<your_key>", ... }` with the
        fields your strategy requires. The endpoint returns the same Spree-issued
        JWT regardless of which strategy authenticated the request.
      DESC

      admin_sdk_example 'auth/login'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        oneOf: [
          {
            title: 'EmailPasswordLogin',
            description: 'Built-in email/password authentication (default when `provider` is omitted).',
            type: :object,
            properties: {
              provider: { type: :string, enum: ['email'], default: 'email' },
              email: { type: :string, format: 'email', example: 'admin@example.com' },
              password: { type: :string, example: 'password123' }
            },
            required: %w[email password]
          },
          {
            title: 'ProviderLogin',
            description: <<~D,
              Provider-dispatched login. The `provider` key selects a registered
              strategy class; the remaining fields are forwarded to the strategy's
              `authenticate` method. Required fields depend on the registered strategy
              — consult its documentation.
            D
            type: :object,
            properties: {
              provider: { type: :string, example: 'okta', description: 'Registered provider key (anything other than `email`).' }
            },
            required: %w[provider],
            additionalProperties: true
          }
        ]
      }

      response '200', 'login successful' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { email: existing_admin.email, password: 'password123' } }

        schema '$ref' => '#/components/schemas/AuthResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['user']).to be_present
          expect(data['user']['email']).to eq(existing_admin.email)
          expect(data).not_to have_key('refresh_token')
        end
      end

      response '401', 'invalid credentials' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { email: existing_admin.email, password: 'wrong_password' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/auth/refresh' do
    post 'Refresh token' do
      tags 'Authentication'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Exchanges the HttpOnly refresh-token cookie for a new access JWT and a
        rotated refresh token cookie. No request body or Authorization header
        is required — the cookie alone authenticates the call.
      DESC

      admin_sdk_example 'auth/refresh'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true

      response '401', 'missing or invalid refresh-token cookie' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/auth/logout' do
    post 'Logout' do
      tags 'Authentication'
      produces 'application/json'
      security [api_key: []]
      description 'Revokes the refresh-token cookie, effectively logging the admin out.'

      admin_sdk_example 'auth/logout'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true

      response '204', 'logout successful' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end
end
