module Spree
  module Api
    module V3
      # Sets X-RateLimit-Limit, X-RateLimit-Remaining, and Retry-After headers
      # on every Store API response by reading the same cache counter that
      # Rails' built-in `rate_limit` writes to.
      module RateLimitHeaders
        extend ActiveSupport::Concern

        included do
          after_action :set_rate_limit_headers
        end

        private

        def set_rate_limit_headers
          limit = Spree::Api::Config[:rate_limit_per_key]
          by = request.headers['X-Spree-Api-Key'] || request.remote_ip
          cache_key = ['rate-limit', controller_path, by].compact.join(':')
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
