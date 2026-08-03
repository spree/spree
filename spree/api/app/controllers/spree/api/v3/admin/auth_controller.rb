module Spree
  module Api
    module V3
      module Admin
        class AuthController < Admin::BaseController
          include Spree::Api::V3::Admin::AuthCookies
          include Spree::Api::V3::AuthenticationStrategies

          skip_scope_check!

          rate_limit to: Spree::Api::Config[:rate_limit_login], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: [:create, :providers, :callback], with: RATE_LIMIT_RESPONSE
          rate_limit to: Spree::Api::Config[:rate_limit_refresh], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: [:refresh, :logout], with: RATE_LIMIT_RESPONSE

          skip_before_action :authenticate_admin!, only: [:create, :refresh, :logout, :providers, :callback]

          # POST /api/v3/admin/auth/login
          def create
            strategy = authentication_strategy
            return unless strategy

            result = strategy.authenticate

            if result.success?
              user = result.value
              refresh_token = Spree::RefreshToken.create_for(user, request_env: request_env_for_token)
              set_refresh_cookie(refresh_token)
              render json: auth_response(user)
            else
              render_error(
                code: ERROR_CODES[:authentication_failed],
                message: result.error,
                status: :unauthorized
              )
            end
          end

          # GET /api/v3/admin/auth/providers
          #
          # Lists the registered authentication providers so the dashboard login
          # page can render itself: the password form when :email is registered,
          # a button per redirect provider. Unauthenticated — it is read before
          # anyone can log in — so it exposes only provider keys, kinds, labels
          # and authorization URLs.
          def providers
            described = Spree.admin_authentication_strategies.describe { |key| issue_oauth_state(key) }

            render json: { providers: described }
          end

          # GET /api/v3/admin/auth/callback/:provider
          #
          # Completes a redirect (SSO) login. Terminates in the same access JWT +
          # refresh-token cookie the password flow issues — no separate session
          # mechanism for SSO.
          def callback
            return render_invalid_state unless valid_oauth_state?

            strategy = authentication_strategy(params[:provider])
            return unless strategy

            result = strategy.callback

            if result.success?
              user = result.value
              refresh_token = Spree::RefreshToken.create_for(user, request_env: request_env_for_token)
              set_refresh_cookie(refresh_token)
              render json: auth_response(user)
            else
              render_error(
                code: ERROR_CODES[:account_not_provisioned],
                message: result.error,
                status: :unauthorized
              )
            end
          end

          # POST /api/v3/admin/auth/refresh
          def refresh
            refresh_token_value = refresh_token_from_cookie

            if refresh_token_value.blank?
              return render_error(
                code: ERROR_CODES[:invalid_refresh_token],
                message: 'Refresh token cookie missing',
                status: :unauthorized
              )
            end

            refresh_token = Spree::RefreshToken.active.find_by(token: refresh_token_value)

            if refresh_token.nil?
              clear_refresh_cookie
              return render_error(
                code: ERROR_CODES[:invalid_refresh_token],
                message: 'Invalid or expired refresh token',
                status: :unauthorized
              )
            end

            user = refresh_token.user
            new_refresh_token = refresh_token.rotate!(request_env: request_env_for_token)
            set_refresh_cookie(new_refresh_token)

            render json: auth_response(user)
          end

          # POST /api/v3/admin/auth/logout
          def logout
            refresh_token_value = refresh_token_from_cookie
            Spree::RefreshToken.active.find_by(token: refresh_token_value)&.destroy if refresh_token_value.present?

            clear_refresh_cookie
            head :no_content
          end

          private

          OAUTH_STATE_PURPOSE = 'spree/admin/oauth_state'.freeze
          OAUTH_STATE_EXPIRY = 15.minutes

          # Signed, self-expiring CSRF token handed to the identity provider and
          # echoed back to the callback. Signing it means no server-side session
          # storage — the token proves the redirect started here, and a forged or
          # expired value fails verification.
          #
          # The provider key is signed into the payload so a state minted for one
          # provider cannot be replayed against another's callback.
          def issue_oauth_state(provider)
            Rails.application.message_verifier(OAUTH_STATE_PURPOSE).generate(
              { provider: provider.to_s, nonce: SecureRandom.hex(16) },
              expires_in: OAUTH_STATE_EXPIRY
            )
          end

          def valid_oauth_state?
            state = params[:state]
            return false if state.blank?

            # The verifier round-trips through JSON, so payload keys come back as strings.
            payload = Rails.application.message_verifier(OAUTH_STATE_PURPOSE).verified(state)
            return false unless payload.is_a?(Hash)

            payload['provider'].to_s == params[:provider].to_s
          end

          def render_invalid_state
            render_error(
              code: ERROR_CODES[:invalid_oauth_state],
              message: Spree.t('errors.messages.invalid_oauth_state'),
              status: :unauthorized
            )
          end

          def authentication_strategies
            Spree.admin_authentication_strategies
          end

          def authentication_user_class
            Spree.admin_user_class
          end

          def serializer_params
            {
              store: current_store,
              locale: current_locale,
              currency: current_currency,
              user: current_user,
              includes: []
            }
          end

          def auth_response(user)
            {
              token: generate_jwt(user, audience: JWT_AUDIENCE_ADMIN),
              user: admin_user_serializer.new(user, params: serializer_params).to_h
            }
          end

          def request_env_for_token
            {
              ip_address: request.remote_ip,
              user_agent: request.user_agent&.truncate(255)
            }
          end

          def admin_user_serializer
            Spree.api.admin_admin_user_serializer
          end

          # Admin tokens have higher blast radius than customer tokens, so they get a
          # shorter TTL (5 min by default) — overrides the storefront default (1h).
          def jwt_expiration
            Spree::Api::Config[:admin_jwt_expiration]
          end
        end
      end
    end
  end
end
