module Spree
  module Api
    module V3
      class BaseSerializer
        attr_reader :resource, :context, :includes

        def initialize(resource, context = {})
          @resource = resource
          @context = context
          @includes = Array(context[:includes] || [])
        end

        # Main serialization method
        def as_json
          attributes
        end

        protected

        # Override in subclasses to define attributes
        def attributes
          {
            id: resource.id
          }
        end

        # Check if an association should be included
        # @param association [String, Symbol] The association name
        # @return [Boolean]
        def include?(association)
          includes.include?(association.to_s)
        end

        # Get nested includes for a parent association
        # @param parent [String, Symbol] The parent association
        # @return [Array<String>]
        def nested_includes_for(parent)
          prefix = "#{parent}."
          includes
            .select { |inc| inc.start_with?(prefix) }
            .map { |inc| inc.sub(prefix, '') }
        end

        # Context for nested serializers
        # @param parent [String, Symbol] The parent association name
        # @return [Hash]
        def nested_context(parent = nil)
          ctx = context.dup
          ctx[:includes] = parent ? nested_includes_for(parent) : []
          ctx
        end

        # Context helpers
        def currency
          context[:currency]
        end

        def store
          context[:store]
        end

        def user
          context[:user]
        end

        def locale
          context[:locale]
        end

        # Price helpers
        def money_to_hash(money)
          return nil unless money

          {
            amount: money.to_f,
            currency: money.currency.iso_code,
            formatted: money.to_s
          }
        end

        def price_in_currency(priceable)
          return nil unless priceable.respond_to?(:price_in)

          priceable.price_in(currency)
        end

        # Image URL helper
        def image_url(image, size: nil)
          return nil unless image&.attached?

          url_helpers.cdn_image_url(image.attachment)
        end

        def url_helpers
          Rails.application.routes.url_helpers
        end

        # Timestamp helper
        def timestamp(time)
          time&.iso8601
        end
      end
    end
  end
end
