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

        # Every request header that changes a publicly cacheable response.
        # A shared cache (CDN, reverse proxy) keys stored responses on these,
        # so a header missing here lets one visitor's response be served to
        # another:
        # - +Accept+ — response format
        # - +X-Spree-Api-Key+ — the publishable key selects the store (and
        #   may bind a channel)
        # - +Authorization+ — a customer JWT turns the response private
        #   (customer-group prices, gated catalog); without it a guest
        #   response could be served to a signed-in customer
        # - +X-Spree-Country+ — selects the market (currency, prices, tax
        #   display, availability)
        # - +X-Spree-Currency+ / +X-Spree-Locale+ — currency and language
        # - +X-Spree-Channel+ — price hiding + channel-scoped visibility
        #
        # Query-param equivalents (+?country=+, +?currency=+, +?locale=+)
        # are part of the URL and so already part of every cache key.
        VARY_HEADERS = %w[
          Accept
          X-Spree-Api-Key
          Authorization
          X-Spree-Country
          X-Spree-Currency
          X-Spree-Locale
          X-Spree-Channel
        ].freeze

        included do
          after_action :set_vary_headers
        end

        protected

        # Check if the current user is a guest (no authentication)
        def guest_user?
          current_user.nil?
        end

        # Set Vary so a shared cache stores one guest response per
        # store/market/currency/locale/channel combination (see VARY_HEADERS).
        def set_vary_headers
          if guest_user?
            response.headers['Vary'] = VARY_HEADERS.join(', ')
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
          if request.fresh?(response)
            head :not_modified
            false
          else
            true
          end
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

          # Use Rails' stale? which handles ETag and Last-Modified. The request
          # context (currency, locale, market, channel) is folded into the ETag
          # so a revalidation never 304s across contexts; Last-Modified mirrors
          # the resource's own timestamp as before.
          stale?(
            etag: [resource, current_currency, current_locale, cache_market_fragment, cache_channel_fragment],
            last_modified: resource.try(:updated_at),
            public: true
          )
        end

        private

        # Build a cache key for a collection
        # Includes: latest updated_at, total count, query params, pagination, expand, currency, locale, market, channel
        def collection_cache_key(collection)
          # For ActiveRecord collections use updated_at, for plain arrays use store's updated_at as proxy
          latest_updated_at = if collection.first&.respond_to?(:updated_at)
                                collection.map(&:updated_at).max&.to_i
                              else
                                current_store&.updated_at&.to_i
                              end

          parts = [
            latest_updated_at,
            @pagy&.count || collection.size,
            params[:expand],
            params[:fields],
            params[:q]&.to_json,
            params[:page],
            params[:limit],
            current_currency,
            current_locale,
            cache_market_fragment,
            cache_channel_fragment
          ]

          parts.compact.join('/')
        end

        # Identifies the resolved market (from X-Spree-Country / ?country=).
        # The market drives tax display and availability as well as currency,
        # so it is part of the guest cache identity.
        def cache_market_fragment
          Spree::Current.market&.id
        end

        # Identifies the resolved channel for cache-key purposes. The channel
        # changes the serialized body (price hiding + channel-scoped visibility),
        # so it must be part of the guest cache identity. Uses the same
        # +current_channel+ source of truth as serialization/gating.
        def cache_channel_fragment
          return nil unless respond_to?(:current_channel, true)

          current_channel&.id
        end
      end
    end
  end
end
