module Spree
  module Api
    module V3
      # Provides HTTP caching support for API v3 controllers
      #
      # Strategy:
      # - Guest users: Public HTTP caching with CDN support (5-15 min TTL)
      # - Authenticated users: Private, no-store (no caching)
      #
      # Uses ETag and Last-Modified headers for cache validation.
      module HttpCaching
        extend ActiveSupport::Concern

        included do
          before_action :set_vary_headers
        end

        protected

        # Check if the current user is a guest (no authentication)
        def guest_user?
          current_user.nil?
        end

        # Set Vary headers to ensure proper CDN caching by currency/locale
        def set_vary_headers
          if guest_user?
            response.headers['Vary'] = 'Accept, x-spree-currency, x-spree-locale'
          else
            response.headers['Cache-Control'] = 'private, no-store'
          end
        end

        # Apply HTTP caching for a collection (index actions)
        # Only caches for guest users
        #
        # @param collection [ActiveRecord::Relation] The collection to cache
        # @param expires_in [ActiveSupport::Duration] Cache TTL (default: 5 minutes)
        # @param stale_while_revalidate [ActiveSupport::Duration] Allow stale responses while revalidating
        # @return [Boolean] true if response should be rendered, false if 304 Not Modified
        def cache_collection(collection, expires_in: 5.minutes, stale_while_revalidate: 30.seconds)
          return true unless guest_user?

          expires_in expires_in, public: true, stale_while_revalidate: stale_while_revalidate

          # Use collection's cache key for ETag
          cache_key = collection_cache_key(collection)
          response.headers['ETag'] = %("#{Digest::MD5.hexdigest(cache_key)}")

          # Return false if client has fresh cache (304 Not Modified)
          !request.fresh?(response)
        end

        # Apply HTTP caching for a single resource (show actions)
        # Only caches for guest users
        #
        # @param resource [ActiveRecord::Base] The resource to cache
        # @param expires_in [ActiveSupport::Duration] Cache TTL (default: 5 minutes)
        # @return [Boolean] true if response should be rendered, false if 304 Not Modified
        def cache_resource(resource, expires_in: 5.minutes)
          return true unless guest_user?

          expires_in expires_in, public: true

          # Use Rails' stale? which handles ETag and Last-Modified
          stale?(resource, public: true)
        end

        private

        # Build a cache key for a collection
        # Includes: query params, pagination, includes, currency, locale
        # Strips order to avoid PostgreSQL errors with DISTINCT + subquery ORDER BY expressions
        def collection_cache_key(collection)
          parts = [
            collection.reorder(nil).cache_key_with_version,
            params[:include],
            params[:q],
            params[:page],
            params[:per_page],
            current_currency,
            current_locale
          ]

          parts.compact.join('/')
        end
      end
    end
  end
end
