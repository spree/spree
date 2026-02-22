module Spree
  module Api
    module V3
      class BaseSerializer
        include Alba::Resource
        include Typelizer::DSL

        # Common type hints for fields present in most serializers
        typelize id: :string, created_at: :string, updated_at: :string

        # Use prefixed IDs (Stripe-style) for all API v3 serializers
        # e.g., prod_86Rf07xd4z, variant_k5nR8xLq, or_m3Rp9wXz
        attribute :id do |object|
          next nil unless object.respond_to?(:prefixed_id)

          object.prefixed_id
        end

        # Context accessors
        def current_store
          params[:store]
        end

        def current_currency
          params[:currency]
        end

        def current_user
          params[:user]
        end

        def current_locale
          params[:locale]
        end

        def includes
          @includes ||= Array(params[:includes] || [])
        end

        # Check if an association should be included
        def include?(name)
          includes.include?(name.to_s)
        end

        # Get nested includes for a given parent
        def nested_includes_for(parent)
          prefix = "#{parent}."
          includes.select { |i| i.start_with?(prefix) }.map { |i| i.sub(prefix, '') }
        end

        # Build nested params for child serializers
        def nested_params(parent = nil)
          params.merge(includes: parent ? nested_includes_for(parent) : [])
        end

        # Returns price for a variant using full Price List resolution
        # This may return a price from a price list if applicable
        # Memoized per variant to avoid duplicate queries
        def price_for(variant, quantity: nil)
          return nil unless variant.respond_to?(:price_for)

          @price_for_cache ||= {}
          cache_key = [variant.id, quantity]
          return @price_for_cache[cache_key] if @price_for_cache.key?(cache_key)

          @price_for_cache[cache_key] = variant.price_for(
            currency: current_currency,
            store: current_store,
            user: current_user,
            quantity: quantity
          )
        end

        # Returns the base price for a variant without Price List resolution
        # This is the "original" price before any price list discounts
        # Memoized per variant to avoid duplicate queries
        def price_in(variant)
          return nil unless variant.respond_to?(:price_in)

          @price_in_cache ||= {}
          return @price_in_cache[variant.id] if @price_in_cache.key?(variant.id)

          @price_in_cache[variant.id] = variant.price_in(current_currency)
        end

        def image_url_for(image)
          return nil if image.nil?
          return nil unless image.respond_to?(:attached?) && image.attached?

          # Handle Spree::Asset models (like Spree::Image) which have attachment inside
          # vs direct ActiveStorage attachments (like taxon.image)
          attachment = image.is_a?(Spree::Asset) ? image.attachment : image
          Rails.application.routes.url_helpers.cdn_image_url(attachment)
        end
      end
    end
  end
end
