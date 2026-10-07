module Spree
  module Api
    module V3
      module Idempotent
        extend ActiveSupport::Concern

        IDEMPOTENCY_TTL = 24.hours
        IDEMPOTENCY_HEADER = 'Idempotency-Key'
        MAX_KEY_LENGTH = 255

        MUTATING_METHODS = %w[POST PUT PATCH DELETE].freeze

        included do
          around_action :check_idempotency, if: :mutating_request?
        end

        private

        def check_idempotency
          key = request.headers[IDEMPOTENCY_HEADER]
          return yield if key.blank?

          if key.length > MAX_KEY_LENGTH
            render_error(
              code: ErrorHandler::ERROR_CODES[:invalid_request],
              message: "Idempotency-Key must be #{MAX_KEY_LENGTH} characters or less.",
              status: :bad_request
            )
            return
          end

          return yield if caller_identity.nil?

          cache_key = idempotency_cache_key(key)
          cached = Rails.cache.read(cache_key)

          if cached
            if cached[:fingerprint] != request_fingerprint
              render_error(
                code: ErrorHandler::ERROR_CODES[:idempotency_key_reused],
                message: I18n.t('spree.idempotency_key_reused'),
                status: :unprocessable_content
              )
              return
            end

            self.response_body = cached[:body]
            self.status = cached[:status]
            response.content_type = cached[:content_type] if cached[:content_type]
            response.headers['Idempotent-Replayed'] = 'true'
            return
          end

          yield

          # Cache 2xx and 4xx responses, skip 5xx (transient server errors should be retryable)
          if response.status < 500
            Rails.cache.write(cache_key, {
              body: response.body,
              status: response.status,
              content_type: response.content_type,
              fingerprint: request_fingerprint
            }, expires_in: IDEMPOTENCY_TTL)
          end
        end

        def mutating_request?
          MUTATING_METHODS.include?(request.method)
        end

        def caller_identity
          return @caller_identity if defined?(@caller_identity)

          credentials = []

          credentials << ['secret_key', Spree::ApiKey.compute_token_digest(extract_api_key)] if secret_key_request?

          bearer_token = extract_token
          credentials << ['bearer', Digest::SHA256.hexdigest(bearer_token)] if bearer_token.present?

          credentials << ['order_token', Digest::SHA256.hexdigest(order_token)] if order_token.present?

          @caller_identity = credentials.presence
        end

        def idempotency_cache_key(key)
          # The resolved store partitions the namespace: a staff JWT spans
          # stores, and replaying one store's cached response for a request
          # aimed at another would cross store boundaries. The resolved
          # store — not the raw header — so a header naming the default store
          # and no header at all land in the same partition, as they resolve
          # to the same store.
          digest = Digest::SHA256.hexdigest([*caller_identity.flatten, current_store&.id, key].join("\0"))
          "spree:idempotency:#{digest}"
        end

        def request_fingerprint
          Digest::SHA256.hexdigest("#{request.method}:#{request.path}:#{request.raw_post}")
        end
      end
    end
  end
end
