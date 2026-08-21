module Spree
  module Variants
    # Updates a variant, reconciling the option values, prices and stock
    # levels the payload carries (see Spree::Variants::NestedAttributes —
    # prices replace, stock levels and options upsert).
    #
    # Handlers reading `variant.changes` in :validate see the pending edit
    # before it is written.
    class Update < Spree::Workflow
      include Spree::Variants::NestedAttributes

      hooks :validate, :after_update

      # @param variant [Spree::Variant]
      # @param attributes [Hash] may carry `options`, `prices`, `stock_levels`
      # @return [Spree::ServiceModule::Result] value is the variant
      def perform(variant:, attributes: {})
        super

        step :assign_attributes
        run_hooks :validate

        ApplicationRecord.transaction do
          step :save_variant
          step :apply_nested_attributes
          run_hooks :after_update
        end

        success(variant)
      end

      private

      def assign_attributes
        attrs = attributes.to_h.with_indifferent_access

        @options_params = attrs.delete(:options)
        @prices_params = attrs.delete(:prices)
        @stock_levels_params = attrs.delete(:stock_levels) || attrs.delete(:stock_levels_attributes)

        variant.assign_attributes(attrs)
      end

      def save_variant
        failure(variant) unless variant.save
      end

      def apply_nested_attributes
        apply_options(variant, @options_params)
        apply_prices(variant, @prices_params)
        apply_stock_levels(variant, @stock_levels_params)
      end
    end
  end
end
