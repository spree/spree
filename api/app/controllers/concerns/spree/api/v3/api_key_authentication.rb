module Spree
  module Api
    module V3
      module ApiKeyAuthentication
        extend ActiveSupport::Concern

        included do
          attr_reader :current_api_key
        end

        def authenticate_api_key!
          @current_api_key = current_store.api_keys.active.publishable.find_by(token: extract_api_key)

          unless @current_api_key
            render_error(
              code: ErrorHandler::ERROR_CODES[:invalid_token],
              message: 'Valid API key required',
              status: :unauthorized
            )
            return false
          end

          Spree::ApiKeyTouchJob.perform_later(@current_api_key.id)
          true
        end

        def authenticate_secret_key!
          @current_api_key = current_store.api_keys.active.secret.find_by(token: extract_api_key)

          unless @current_api_key
            render_error(
              code: ErrorHandler::ERROR_CODES[:invalid_token],
              message: 'Valid secret API key required',
              status: :unauthorized
            )
            return false
          end

          Spree::ApiKeyTouchJob.perform_later(@current_api_key.id)
          true
        end

        def admin_context?
          @current_api_key&.secret? || current_user&.try(:spree_admin?, current_store)
        end

        private

        def extract_api_key
          request.headers['X-Spree-Api-Key'].presence || params[:api_key]
        end
      end
    end
  end
end
