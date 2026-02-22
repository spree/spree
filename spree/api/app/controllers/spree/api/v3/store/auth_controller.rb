module Spree
  module Api
    module V3
      module Store
        class AuthController < Store::BaseController
          skip_before_action :authenticate_user, only: [:create, :register, :oauth_callback]
          prepend_before_action :require_authentication!, only: [:refresh]

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
              token = generate_jwt(user)
              render json: {
                token: token,
                user: user_serializer.new(user, params: serializer_params).to_h
              }
            else
              render_error(
                code: ERROR_CODES[:authentication_failed],
                message: result.error,
                status: :unauthorized
              )
            end
          end

          # POST  /api/v3/store/auth/register
          def register
            user = Spree.user_class.new(registration_params)

            if user.save
              token = generate_jwt(user)
              render json: {
                token: token,
                user: user_serializer.new(user, params: serializer_params).to_h
              }, status: :created
            else
              render_errors(user.errors)
            end
          end

          # POST  /api/v3/store/auth/refresh
          def refresh
            token = generate_jwt(current_user)
            render json: {
              token: token,
              user: user_serializer.new(current_user, params: serializer_params).to_h
            }
          end

          # POST  /api/v3/store/auth/oauth/callback
          # OAuth callback endpoint for server-side OAuth flows
          def oauth_callback
            # This endpoint is designed for OAuth flows where the server
            # exchanges the authorization code for an access token
            # For client-side flows, use the regular /login endpoint with id_token

            strategy = authentication_strategy
            return unless strategy # Error already rendered by determine_strategy

            result = strategy.authenticate

            if result.success?
              user = result.value
              token = generate_jwt(user)
              render json: {
                token: token,
                user: user_serializer.new(user, params: serializer_params).to_h
              }
            else
              render_error(
                code: ERROR_CODES[:authentication_failed],
                message: result.error,
                status: :unauthorized
              )
            end
          end

          protected

          def serializer_params
            {
              store: current_store,
              locale: current_locale,
              currency: current_currency,
              user: current_user,
              includes: []
            }
          end

          private

          def authentication_strategy
            strategy_class = determine_strategy
            strategy_class.new(
              params: params,
              request_env: request.headers.env,
              user_class: Spree.user_class
            )
          end

          def determine_strategy
            provider = params[:provider].presence || 'email'
            provider_key = provider.to_sym

            # Retrieve pre-loaded strategy class from configuration
            strategy_class = Rails.application.config.spree.store_authentication_strategies[provider_key]

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

          def registration_params
            params.permit(:email, :password, :password_confirmation, :first_name, :last_name)
          end

          def user_serializer
            Spree.api.customer_serializer
          end
        end
      end
    end
  end
end
