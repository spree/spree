module Spree
  module Api
    module V3
      module Store
        class AuthController < Store::BaseController
          include Spree::Api::V3::AuthenticationStrategies

          allow_guest_storefront_access!
          # Tighter rate limits for auth endpoints (per IP to prevent brute
          # force). Distinct `name:` per declaration — without one, Rails keys
          # every counter in this controller on the same (controller, client)
          # cache entry, silently merging the budgets.
          rate_limit to: Spree::Api::Config[:rate_limit_login], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: :create, name: 'login', with: -> { render_rate_limited(limit: Spree::Api::Config[:rate_limit_login]) }
          rate_limit to: Spree::Api::Config[:rate_limit_refresh], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: :refresh, name: 'refresh', with: -> { render_rate_limited(limit: Spree::Api::Config[:rate_limit_refresh]) }
          rate_limit to: Spree::Api::Config[:rate_limit_refresh], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: :logout, name: 'logout', with: -> { render_rate_limited(limit: Spree::Api::Config[:rate_limit_refresh]) }

          skip_before_action :authenticate_user, only: [:create, :refresh, :logout]

          # POST  /api/v3/store/auth/login
          # Supports multiple authentication providers via :provider param
          # Example:
          #   { "provider": "email", "email": "...", "password": "..." }
          def create
            strategy = authentication_strategy
            return unless strategy # Error already rendered by authentication_strategy

            result = strategy.authenticate

            if result.success?
              user = result.value
              render json: auth_response(user)
            else
              render_error(
                code: ERROR_CODES[:authentication_failed],
                message: result.error,
                status: :unauthorized
              )
            end
          end

          # POST  /api/v3/store/auth/refresh
          # Accepts: { "refresh_token": "rt_xxx" }
          # Returns new access JWT + rotated refresh token
          def refresh
            refresh_token_value = params[:refresh_token]

            if refresh_token_value.blank?
              return render_error(
                code: ERROR_CODES[:invalid_refresh_token],
                message: 'refresh_token is required',
                status: :unauthorized
              )
            end

            refresh_token = Spree::RefreshToken.active.for_audience(JWT_AUDIENCE_STORE).find_by(token: refresh_token_value)

            if refresh_token.nil?
              return render_error(
                code: ERROR_CODES[:invalid_refresh_token],
                message: 'Invalid or expired refresh token',
                status: :unauthorized
              )
            end

            user = refresh_token.user
            new_refresh_token = refresh_token.rotate!(request_env: request_env_for_token)

            render json: {
              token: generate_jwt(user),
              refresh_token: new_refresh_token.token,
              user: user_serializer.new(user, params: serializer_params).to_h
            }
          end

          # POST  /api/v3/store/auth/logout
          # Accepts: { "refresh_token": "rt_xxx" }
          # Revokes the submitted refresh token. The token itself is the
          # credential — no access JWT is required, so clients with an expired
          # access token can still log out. Narrowed to this surface's own
          # tokens: ending a session belongs to the surface that started it.
          def logout
            refresh_token_value = params[:refresh_token]

            if refresh_token_value.present?
              Spree::RefreshToken.for_audience(JWT_AUDIENCE_STORE).find_by(token: refresh_token_value)&.destroy
            end

            head :no_content
          end

          protected

          def serializer_params
            {
              store: current_store,
              locale: current_locale,
              currency: current_currency,
              user: current_user,
              includes: [],
              hide_prices: hide_prices?
            }
          end

          private

          def auth_response(user)
            refresh_token = Spree::RefreshToken.create_for(user, audience: JWT_AUDIENCE_STORE, request_env: request_env_for_token)

            {
              token: generate_jwt(user),
              refresh_token: refresh_token.token,
              user: user_serializer.new(user, params: serializer_params).to_h
            }
          end

          def request_env_for_token
            {
              ip_address: request.remote_ip,
              user_agent: request.user_agent&.truncate(255)
            }
          end

          def authentication_strategies
            Spree.store_authentication_strategies
          end

          def authentication_user_class
            Spree.customer_class
          end

          def user_serializer
            Spree.api.customer_serializer
          end
        end
      end
    end
  end
end
