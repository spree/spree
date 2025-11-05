module Spree
  module Api
    module V3
      module Storefront
        class AuthController < BaseController
          include Spree::Api::V3::Storefront::Authentication

          skip_before_action :authenticate_user, only: [:create, :register, :oauth_callback]
          before_action :require_authentication!, only: [:refresh]

          # POST /api/v3/storefront/auth/login
          # Supports multiple authentication providers via :provider param
          # Examples:
          #   { "provider": "email", "email": "...", "password": "..." }
          #   { "provider": "google", "id_token": "..." }
          def create
            strategy = authentication_strategy
            return unless strategy # Error already rendered by determine_strategy

            result = strategy.authenticate

            if result.success?
              user = result.value
              token = generate_jwt(user)
              render json: {
                token: token,
                user: user_serializer.new(user, serializer_context).as_json
              }
            else
              render_error(
                code: ERROR_CODES[:authentication_failed],
                message: result.error,
                status: :unauthorized
              )
            end
          end

          # POST /api/v3/storefront/auth/register
          def register
            user = Spree.user_class.new(registration_params)

            if user.save
              token = generate_jwt(user)
              render json: {
                token: token,
                user: user_serializer.new(user, serializer_context).as_json
              }, status: :created
            else
              render_errors(user.errors)
            end
          end

          # POST /api/v3/storefront/auth/refresh
          def refresh
            token = generate_jwt(current_user)
            render json: {
              token: token,
              user: user_serializer.new(current_user, serializer_context).as_json
            }
          end

          # POST /api/v3/storefront/auth/oauth/callback
          # OAuth callback endpoint for server-side OAuth flows
          # Example: { "provider": "google", "code": "authorization_code" }
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
                user: user_serializer.new(user, serializer_context).as_json
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

          def serializer_context
            {
              store: current_store,
              locale: current_locale
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
            strategy_class = Rails.application.config.spree.authentication_strategies[provider_key]

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
            params.require(:user).permit(:email, :password, :password_confirmation, :first_name, :last_name)
          end

          def user_serializer
            Spree::Api::Dependencies.v3_storefront_user_serializer.constantize
          end
        end
      end
    end
  end
end
