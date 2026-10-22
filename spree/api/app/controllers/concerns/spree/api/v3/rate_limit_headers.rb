module Spree
  module Api
    module V3
      # Owns the request-throttling identity shared by the `rate_limit`
      # declarations in BaseController and the X-RateLimit-Limit /
      # X-RateLimit-Remaining / Retry-After headers set on every v3 response:
      # which bucket a request counts against and which ceiling applies.
      #
      # Secret keys (sk_*) are single server-to-server callers, so each key
      # gets one bucket across the whole API. Publishable keys (pk_*) are
      # shared by every storefront visitor, so their bucket includes the
      # client IP — the limit is per visitor, never per storefront. A
      # delegated grant (an OAuth token) is one caller the way a secret key
      # is, so it gets a bucket of its own. Requests without any of these
      # (admin JWT traffic) fall back to the client IP.
      module RateLimitHeaders
        extend ActiveSupport::Concern

        # Shared `scope:` for the API-wide throttle — one bucket per caller
        # across all v3 controllers, instead of Rails' default of one bucket
        # per controller.
        RATE_LIMIT_SCOPE = 'api_v3'.freeze

        included do
          after_action :set_rate_limit_headers
        end

        private

        def rate_limit_ceiling
          if secret_key_request?
            Spree::Api::Config[:rate_limit_per_secret_key]
          else
            Spree::Api::Config[:rate_limit_per_key]
          end
        end

        # Secret tokens are digested first — plaintext secrets must never
        # become cache keys (Solid Cache persists them to the database, while
        # the model itself stores only +token_digest+).
        def rate_limit_bucket
          api_key = extract_api_key

          if secret_key_request?
            Spree::ApiKey.compute_token_digest(api_key)
          elsif api_key
            "#{api_key}:#{request.remote_ip}"
          elsif (token = rate_limit_oauth_token)
            "oauth:#{token.id}"
          else
            request.remote_ip
          end
        end

        # Hosted connectors reach the API from a handful of shared addresses,
        # so an address bucket would let one merchant's agent exhaust every
        # other merchant's on the same vendor. Only a token that resolves
        # counts: a bearer value matching nothing stays in the address bucket,
        # so a flood of invented tokens cannot escape it. The lookup is the
        # one authentication memoizes, so it costs no second query.
        def rate_limit_oauth_token
          respond_to?(:admin_oauth_token, true) ? admin_oauth_token : nil
        end

        def set_rate_limit_headers
          limit = rate_limit_ceiling
          cache_key = ['rate-limit', RATE_LIMIT_SCOPE, rate_limit_bucket].join(':')
          count = Rails.cache.read(cache_key)

          return if count.nil?

          response.headers['X-RateLimit-Limit'] = limit.to_s
          response.headers['X-RateLimit-Remaining'] = [limit - count.to_i, 0].max.to_s
          response.headers['Retry-After'] = Spree::Api::Config[:rate_limit_window].to_s if count.to_i >= limit
        end
      end
    end
  end
end
