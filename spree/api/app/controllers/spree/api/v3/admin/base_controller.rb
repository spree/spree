module Spree
  module Api
    module V3
      module Admin
        class BaseController < Spree::Api::V3::BaseController
          include Spree::Api::V3::RateLimitHeaders

          RATE_LIMIT_RESPONSE = -> {
            limit = Spree::Api::Config[:rate_limit_per_key]
            window = Spree::Api::Config[:rate_limit_window]
            body = { error: { code: 'rate_limit_exceeded', message: 'Too many requests. Please retry later.' } }
            headers = {
              'Content-Type' => 'application/json',
              'Retry-After' => window.to_s,
              'X-RateLimit-Limit' => limit.to_s,
              'X-RateLimit-Remaining' => '0'
            }
            [429, headers, [body.to_json]]
          }

          # Global rate limit per secret API key
          rate_limit to: Spree::Api::Config[:rate_limit_per_key], within: Spree::Api::Config[:rate_limit_window].seconds,
                     store: Rails.cache,
                     by: -> { request.headers['X-Spree-Api-Key'] || request.remote_ip },
                     with: RATE_LIMIT_RESPONSE

          # Require secret API key for all Admin API requests
          before_action :authenticate_secret_key!

          protected

          # Override JWT audience to require admin tokens
          def expected_audience
            JWT_AUDIENCE_ADMIN
          end
        end
      end
    end
  end
end
