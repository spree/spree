module Spree
  module Variants
    # Creates a variant on a product. The single gate for variant creation —
    # the standalone variants endpoint and the nested payload on a product
    # write both run through it, so a :validate handler sees every variant a
    # catalog gains.
    #
    # The product is a parameter rather than something read off the payload
    # because everything nested needs it: an option value attaches an option
    # type to the product, and a stock location is resolved through the
    # product's store. The model defers those writes when it is built without
    # an owner; a caller of this workflow has already named one, so they
    # apply directly.
    class Create < Spree::Workflow
      include Spree::Variants::NestedAttributes

      hooks :validate, :after_create

      # The unsaved record a :validate handler reads.
      attr_reader :variant

      # @param product [Spree::Product]
      # @param attributes [Hash] may carry `options`, `prices`, `stock_levels`
      # @return [Spree::ServiceModule::Result] value is the variant
      def perform(product:, attributes: {})
        super

        step :build_variant
        run_hooks :validate

        ApplicationRecord.transaction do
          step :save_variant
          step :apply_nested_attributes
          run_hooks :after_create
        end

        success(variant)
      end

      private

      def build_variant
        attrs = attributes.to_h.with_indifferent_access

        @options_params = attrs.delete(:options)
        @prices_params = attrs.delete(:prices)
        @stock_levels_params = attrs.delete(:stock_levels) || attrs.delete(:stock_levels_attributes)

        @variant = product.variants.new(attrs)
      end

      def save_variant
        failure(variant) unless variant.save
      end

      # Options first: an option value attaches its option type to the
      # product, and the variant's identity depends on it before prices or
      # stock mean anything.
      def apply_nested_attributes
        apply_options(variant, @options_params)
        apply_prices(variant, @prices_params)
        apply_stock_levels(variant, @stock_levels_params)
      end
    end
  end
end
