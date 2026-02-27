module Spree
  module Api
    module V3
      module ApiKeyAuthentication
        extend ActiveSupport::Concern

        included do
          # @!attribute [r] current_api_key
          #   The authenticated API key for the current request.
          #   @return [Spree::ApiKey, nil]
          attr_reader :current_api_key
        end

        # Authenticates a publishable API key (pk_*) for Store API requests.
        # Looks up the key by plaintext token scoped to the current store.
        #
        # @return [Boolean] true if authentication succeeded, false otherwise
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

        # Authenticates a secret API key (sk_*) for Admin API requests.
        # Computes the HMAC-SHA256 digest of the provided token and looks up
        # by +token_digest+, then verifies it belongs to the current store.
        #
        # @return [Boolean] true if authentication succeeded, false otherwise
        def authenticate_secret_key!
          @current_api_key = Spree::ApiKey.find_by_secret_token(extract_api_key)
          @current_api_key = nil if @current_api_key && @current_api_key.store_id != current_store.id

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

        private

        # Extracts the API key from the request headers or params.
        #
        # @return [String, nil] the API key token
        def extract_api_key
          request.headers['X-Spree-Api-Key'].presence || params[:api_key]
        end
      end
    end
  end
end
