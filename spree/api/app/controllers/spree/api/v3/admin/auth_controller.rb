module Spree
  module Api
    module V3
      module Admin
        class AuthController < Admin::BaseController
          include Spree::Api::V3::Admin::AuthCookies
          include Spree::Api::V3::AuthenticationStrategies

          skip_scope_check!

          # The SSO callback answers a browser navigation, so a throttled request
          # must return the person to the login page rather than a JSON body they
          # cannot act on. It also gets its own bucket: completing a sign-in must
          # not be refused because the login form was submitted a few times.
          RATE_LIMITED_CALLBACK_RESPONSE = -> { redirect_to_dashboard(error: 'rate_limit_exceeded') }

          # Each declaration carries a distinct `name:` — without one, Rails
          # keys every counter in this controller on the same
          # (controller, client) cache entry, silently merging the budgets.
          # The login page fetches providers on every load, so sharing the
          # login budget would let ordinary page views — or an attacker
          # hitting providers alone — lock staff out of signing in.
          rate_limit to: Spree::Api::Config[:rate_limit_login], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: :create, name: 'login', with: -> { render_rate_limited(limit: Spree::Api::Config[:rate_limit_login]) }
          rate_limit to: Spree::Api::Config[:rate_limit_refresh], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: :providers, name: 'providers', with: -> { render_rate_limited(limit: Spree::Api::Config[:rate_limit_refresh]) }
          rate_limit to: Spree::Api::Config[:rate_limit_login], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: :callback, name: 'callback', with: RATE_LIMITED_CALLBACK_RESPONSE
          rate_limit to: Spree::Api::Config[:rate_limit_refresh], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: [:refresh, :logout], name: 'refresh', with: -> { render_rate_limited(limit: Spree::Api::Config[:rate_limit_refresh]) }

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
          # Completes a redirect (SSO) login.
          #
          # Reached by a full-page browser redirect from the identity provider, so
          # it answers with a redirect rather than JSON — the browser must land on
          # the dashboard, not on a response body. Success sets the same
          # refresh-token cookie the password flow issues and the SPA mints its
          # access token from it on load, so no token ever travels in a URL.
          def callback
            return redirect_to_dashboard(error: ERROR_CODES[:invalid_oauth_state]) unless valid_oauth_state?

            strategy = Spree.admin_authentication_strategies.build(
              params[:provider],
              params: params,
              request_env: request.headers.env,
              user_class: Spree.admin_user_class
            )
            return redirect_to_dashboard(error: ERROR_CODES[:invalid_provider]) if strategy.nil?

            result = strategy.callback

            unless result.success?
              return redirect_to_dashboard(error: callback_error_code(strategy))
            end

            set_refresh_cookie(Spree::RefreshToken.create_for(result.value, request_env: request_env_for_token))
            redirect_to_dashboard
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

          # The callback answers a browser navigation, so even the API-wide
          # throttle must return the person to the login page — a JSON 429
          # would strand them on a raw error body.
          def render_rate_limited(**)
            return redirect_to_dashboard(error: 'rate_limit_exceeded') if action_name == 'callback'

            super
          end

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

          # Sends the browser back to the dashboard. On failure the login page
          # reads +?error=+ and explains what happened; on success it has the
          # refresh cookie and completes sign-in through its normal boot refresh.
          def redirect_to_dashboard(error: nil)
            target = dashboard_url
            target = "#{target}/login?error=#{error}" if error.present?

            redirect_to target, allow_other_host: true
          end

          # Where the React dashboard is hosted. Falls back to the Vite dev server
          # in development, then to the store's own URL.
          def dashboard_url
            base = Spree::Config[:dashboard_url].presence ||
                   (Rails.env.development? ? 'http://localhost:5173' : nil) ||
                   current_store&.formatted_url

            base.to_s.chomp('/')
          end

          # A technical SSO failure (missing code, token verification) must not be
          # reported as "ask an administrator for an invitation".
          def callback_error_code(strategy)
            if strategy.respond_to?(:account_not_provisioned?) && strategy.account_not_provisioned?
              ERROR_CODES[:account_not_provisioned]
            else
              ERROR_CODES[:authentication_failed]
            end
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
