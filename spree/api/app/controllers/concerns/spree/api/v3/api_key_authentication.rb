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
        # The key SELECTS the store — lookup is global by token and
        # +current_store+ derives from the key (see KeyStoreContext); the key
        # is never validated against a host-resolved store.
        #
        # @return [Boolean] true if authentication succeeded, false otherwise
        def authenticate_api_key!
          @current_api_key = publishable_api_key

          unless @current_api_key
            render_error(
              code: ErrorHandler::ERROR_CODES[:invalid_token],
              message: 'Valid API key required',
              status: :unauthorized
            )
            return false
          end

          touch_api_key_if_needed(@current_api_key)
          true
        end

        # Authenticates a secret API key (sk_*) for Admin API requests.
        # Computes the HMAC-SHA256 digest of the provided token and looks up
        # by +token_digest+. The key is store-bound and selects the request's
        # store (see Admin::StoreContext).
        #
        # @return [Boolean] true if authentication succeeded, false otherwise
        def authenticate_secret_key!
          @current_api_key = secret_api_key

          unless @current_api_key
            render_error(
              code: ErrorHandler::ERROR_CODES[:invalid_token],
              message: 'Valid secret API key required',
              status: :unauthorized
            )
            return false
          end

          touch_api_key_if_needed(@current_api_key)
          true
        end

        private

        # Memoized global publishable-key lookup. Deliberately NOT scoped to
        # +current_store+ — the store derives from the key, not the other way
        # around. Memoizes misses too, so pre-authentication callers (store
        # resolution) don't re-query.
        #
        # @return [Spree::ApiKey, nil]
        def publishable_api_key
          return @publishable_api_key if defined?(@publishable_api_key)

          @publishable_api_key =
            extract_api_key ? Spree::ApiKey.active.publishable.find_by(token: extract_api_key) : nil
        end

        # Memoized global secret-key lookup (digest-based, active keys only).
        #
        # @return [Spree::ApiKey, nil]
        def secret_api_key
          return @secret_api_key if defined?(@secret_api_key)

          @secret_api_key = Spree::ApiKey.find_by_secret_token(extract_api_key)
        end

        # Marks the API key as used at most once per hour
        # to avoid unnecessary DB writes and job queue pressure on every request.
        # This follows the same approach as GitHub's personal access tokens.
        def touch_api_key_if_needed(api_key)
          return if api_key.last_used_at.present? && api_key.last_used_at > 1.hour.ago

          Spree::ApiKeys::MarkAsUsed.perform_later(api_key.id, Time.current)
        end

        # Extracts the API key from the request headers or params.
        #
        # @return [String, nil] the API key token
        def extract_api_key
          request.headers['X-Spree-Api-Key'].presence
        end

        # True when the request presents a secret API key token (`sk_` prefix),
        # regardless of whether authentication has resolved it into
        # `current_api_key` yet. The token is unverified until
        # `authenticate_secret_key!` resolves it, so consumers (the scope
        # guard, rate limiting) must stay fail-closed on this signal alone.
        def secret_key_request?
          extract_api_key.to_s.start_with?(Spree::ApiKey::PREFIXES['secret'])
        end
      end
    end
  end
end
