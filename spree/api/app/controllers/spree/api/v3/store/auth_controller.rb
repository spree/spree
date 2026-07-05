module Spree
  module Api
    module V3
      module Store
        class AuthController < Store::BaseController
          allow_guest_storefront_access!
          # Tighter rate limits for auth endpoints (per IP to prevent brute force)
          rate_limit to: Spree::Api::Config[:rate_limit_login], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: :create, with: RATE_LIMIT_RESPONSE
          rate_limit to: Spree::Api::Config[:rate_limit_refresh], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: :refresh, with: RATE_LIMIT_RESPONSE
          rate_limit to: Spree::Api::Config[:rate_limit_refresh], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: :logout, with: RATE_LIMIT_RESPONSE

          skip_before_action :authenticate_user, only: [:create, :refresh, :logout]

          # POST  /api/v3/store/auth/login
          # Supports multiple authentication providers via :provider param
          # Example:
          #   { "provider": "email", "email": "...", "password": "..." }
          def create
            strategy = authentication_strategy
            return unless strategy # Error already rendered by determine_strategy

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

            refresh_token = Spree::RefreshToken.active.find_by(token: refresh_token_value)

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
          # access token can still log out.
          def logout
            refresh_token_value = params[:refresh_token]

            Spree::RefreshToken.find_by(token: refresh_token_value)&.destroy if refresh_token_value.present?

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
            refresh_token = Spree::RefreshToken.create_for(user, request_env: request_env_for_token)

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

          def authentication_strategy
            strategy_class = determine_strategy
            return nil unless strategy_class

            strategy_class.new(
              params: params,
              request_env: request.headers.env,
              user_class: Spree.user_class
            )
          end

          def determine_strategy
            provider = params[:provider].presence || 'email'

            # Retrieve pre-loaded strategy class from configuration
            strategy_class = Spree.store_authentication_strategies[provider]

            unless strategy_class
              render_error(
                code: ERROR_CODES[:invalid_provider],
                message: "Unsupported authentication provider: #{provider}",
                status: :bad_request
              )
              return nil
            end

            strategy_class
          end

          def user_serializer
            Spree.api.customer_serializer
          end
        end
      end
    end
  end
end
