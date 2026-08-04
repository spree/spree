module Spree
  module Api
    module V3
      # Resolves the authentication strategy a login request asked for, shared by
      # the Store and Admin auth controllers so the unsupported-provider contract
      # (error code, status, message) has exactly one definition.
      #
      # Including controllers supply the registry and user class.
      module AuthenticationStrategies
        extend ActiveSupport::Concern

        private

        # @param provider [String, nil] defaults to the +provider+ param, then :email
        # @return [Object, nil] a strategy instance, or nil after rendering an error
        def authentication_strategy(provider = nil)
          provider ||= params[:provider].presence || 'email'

          strategy = authentication_strategies.build(
            provider,
            params: params,
            request_env: request.headers.env,
            user_class: authentication_user_class
          )

          return strategy if strategy

          render_error(
            code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:invalid_provider],
            message: "Unsupported authentication provider: #{provider}",
            status: :bad_request
          )
          nil
        end

        # @return [Spree::Authentication::StrategyRegistry]
        def authentication_strategies
          raise NotImplementedError, "#{self.class} must implement #authentication_strategies"
        end

        # @return [Class]
        def authentication_user_class
          raise NotImplementedError, "#{self.class} must implement #authentication_user_class"
        end
      end
    end
  end
end
