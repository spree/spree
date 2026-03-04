module Spree
  module Api
    module V3
      module Idempotent
        extend ActiveSupport::Concern

        IDEMPOTENCY_TTL = 24.hours
        IDEMPOTENCY_HEADER = 'Idempotency-Key'
        MAX_KEY_LENGTH = 255

        included do
          around_action :check_idempotency, if: :idempotent_action?
        end

        class_methods do
          def idempotent_actions(*actions)
            self._idempotent_actions = actions.map(&:to_s).freeze
          end

          attr_writer :_idempotent_actions

          def _idempotent_actions
            @_idempotent_actions || []
          end
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

          cache_key = idempotency_cache_key(key)
          cached = Rails.cache.read(cache_key)

          if cached
            if cached[:fingerprint] != request_fingerprint
              render_error(
                code: ErrorHandler::ERROR_CODES[:idempotency_key_reused],
                message: Spree.t(:idempotency_key_reused),
                status: :unprocessable_entity
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

        def idempotent_action?
          self.class._idempotent_actions.include?(action_name)
        end

        def idempotency_cache_key(key)
          owner_id = @current_api_key&.id || spree_current_user&.id || request.remote_ip
          "spree:idempotency:#{owner_id}:#{Digest::SHA256.hexdigest(key)}"
        end

        def request_fingerprint
          Digest::SHA256.hexdigest("#{request.method}:#{request.path}:#{request.raw_post}")
        end
      end
    end
  end
end
