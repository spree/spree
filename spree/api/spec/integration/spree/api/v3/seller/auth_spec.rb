# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Authentication API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let!(:existing_seller_user) do
    create(:admin_user, :without_admin_role, email: 'seller@example.com', password: 'password123').tap do |user|
      seller.add_user(user, seller_role)
    end
  end

  path '/api/v3/seller/auth/login' do
    post 'Login' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      description <<~DESC
        Signs a seller in and returns a short-lived JWT access token carrying the
        `seller_api` audience. The rotatable refresh token is set in an HttpOnly
        cookie — it is not included in the response body.

        The response lists every seller this user may act for. Pick one and send
        its `id` as `X-Spree-Seller-Id` on every subsequent request; nothing else
        on this API answers until a seller is named.

        Authenticating is not on its own enough. A store's own staff share the
        same user class, so a user who runs no seller is refused — issuing a
        token would hand out an audience its holder can do nothing with.

        The `provider` field selects the authentication method. When omitted it
        defaults to `email`. Sellers and store staff read different provider
        registries, so a marketplace can require SSO for its own back office
        while still letting sellers sign in with a password.
      DESC

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          provider: { type: :string, enum: ['email'], default: 'email' },
          email: { type: :string, format: 'email', example: 'seller@example.com' },
          password: { type: :string, example: 'password123' }
        },
        required: %w[email password]
      }

      response '200', 'login successful' do
        let(:body) { { email: existing_seller_user.email, password: 'password123' } }

        schema '$ref' => '#/components/schemas/AuthResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['user']['email']).to eq(existing_seller_user.email)
          expect(data['sellers'].first['id']).to eq(seller.prefixed_id)
          expect(data).not_to have_key('refresh_token')
        end
      end

      response '401', 'invalid credentials' do
        let(:body) { { email: existing_seller_user.email, password: 'wrong_password' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/seller/auth/refresh' do
    post 'Refresh token' do
      tags 'Authentication'
      produces 'application/json'
      description <<~DESC
        Exchanges the HttpOnly refresh-token cookie for a new access JWT and a
        rotated refresh cookie. No request body or Authorization header is
        required — the cookie alone authenticates the call.

        The lookup is narrowed by audience, so a refresh token minted for the
        storefront or the back office cannot be exchanged for a seller session.
        Membership is rechecked here too: a user whose last seller role was
        revoked mid-session is refused rather than renewed.
      DESC

      response '200', 'refresh successful' do
        let(:refresh_token_record) do
          create(:refresh_token, :for_admin, user: existing_seller_user,
                                             audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER)
        end

        # rswag drives requests through Rack::Test, whose cookie jar can't sign
        # cookies the way Rails does. Stub the cookie reader so the integration
        # test can exercise the success path without reimplementing signing.
        before do
          token = refresh_token_record.token
          allow_any_instance_of(Spree::Api::V3::Seller::AuthCookies).to receive(:refresh_token_from_cookie).and_return(token)
        end

        schema '$ref' => '#/components/schemas/AuthResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data).not_to have_key('refresh_token')
        end
      end

      response '401', 'missing or invalid refresh-token cookie' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/seller/auth/logout' do
    post 'Logout' do
      tags 'Authentication'
      produces 'application/json'
      description 'Revokes the refresh-token cookie, ending the seller session.'

      response '204', 'logout successful' do
        run_test!
      end
    end
  end

  path '/api/v3/seller/auth/providers' do
    get 'List authentication providers' do
      tags 'Authentication'
      produces 'application/json'
      description <<~DESC
        The sign-in methods this marketplace offers sellers, for the login page
        to render. Unauthenticated — a login page must be able to ask before
        anyone has signed in.
      DESC

      response '200', 'providers listed' do
        schema '$ref' => '#/components/schemas/AuthProvidersResponse'

        run_test! do |response|
          expect(JSON.parse(response.body)).to have_key('providers')
        end
      end
    end
  end
end
