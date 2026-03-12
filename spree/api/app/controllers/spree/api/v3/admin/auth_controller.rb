module Spree
  module Api
    module V3
      module Admin
        class AuthController < Admin::BaseController
          rate_limit to: Spree::Api::Config[:rate_limit_login], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: :create, with: RATE_LIMIT_RESPONSE
          rate_limit to: Spree::Api::Config[:rate_limit_refresh], within: Spree::Api::Config[:rate_limit_window].seconds, store: Rails.cache, only: :refresh, with: RATE_LIMIT_RESPONSE

          skip_before_action :authenticate_admin!, only: [:create]
          before_action :require_authentication!, only: [:refresh]

          # POST /api/v3/admin/auth/login
          def create
            strategy = authentication_strategy
            return unless strategy

            result = strategy.authenticate

            if result.success?
              user = result.value
              token = generate_jwt(user, audience: JWT_AUDIENCE_ADMIN)
              render json: {
                token: token,
                user: admin_user_serializer.new(user, params: serializer_params).to_h
              }
            else
              render_error(
                code: ERROR_CODES[:authentication_failed],
                message: result.error,
                status: :unauthorized
              )
            end
          end

          # POST /api/v3/admin/auth/refresh
          def refresh
            token = generate_jwt(current_user, audience: JWT_AUDIENCE_ADMIN)
            render json: {
              token: token,
              user: admin_user_serializer.new(current_user, params: serializer_params).to_h
            }
          end

          private

          def authentication_strategy
            provider = params[:provider].presence || 'email'
            strategy_class = Rails.application.config.spree.admin_authentication_strategies[provider.to_sym]

            unless strategy_class
              render_error(
                code: ERROR_CODES[:invalid_provider],
                message: "Unsupported authentication provider: #{provider}",
                status: :bad_request
              )
              return nil
            end

            strategy_class.new(
              params: params,
              request_env: request.headers.env,
              user_class: Spree.admin_user_class
            )
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

          def admin_user_serializer
            Spree.api.admin_admin_user_serializer
          end
        end
      end
    end
  end
end
