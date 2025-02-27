module Spree
  module Storefront
    class VariantFinder
      def initialize(product:, current_currency:, variant_id: nil, options_hash: {})
        @product = product
        @variant_id = variant_id
        @current_currency = current_currency
        @options_hash = options_hash
      end

      def find
        try_variant_from_options
        return [@selected_variant, @variant_from_options] if @selected_variant.present?

        try_any_variant
        [@selected_variant, @variant_from_options]
      end

      private

      attr_reader :current_currency, :options_hash, :variant_id

      def try_variant_from_options
        return unless options_hash.present?
        return unless (@product.option_type_ids.map(&:to_s) - options_hash.keys).empty?

        @product.variants.each do |variant|
          options_matched = options_hash.all? do |option_type_id, name|
            variant.option_values.any? { |ov| ov.option_type_id.to_s == option_type_id && ov.name.downcase.strip == name.downcase.strip }
          end

          if options_matched && variant.purchasable? && variant.price_in(current_currency).amount.present?
            @selected_variant = variant
            @variant_from_options = variant
            break
          elsif options_matched
            @variant_from_options = variant
            break
          end
        end
      end

      def try_any_variant
        if @product.has_variants?
          if options_hash.present? # if selected combination is not purchasable nor active
            @selected_variant = nil
          elsif variant_id.present?
            variant = @product.variants.find(variant_id)
            @variant_from_options = variant
            @selected_variant = variant
          elsif product_option_types.size == 1 && product_option_types.first.color?
            @selected_variant = @variant_from_options = @product.variants.find { |v| v.purchasable? && v.price_in(current_currency).amount.present? }
          elsif @product.variants.size == 1 || product_has_only_one_secondary_option_type_value?
            @variant_from_options = @product.variants.first
            @selected_variant = @variant_from_options
          end
        elsif @product.master.purchasable? && @product.master.price_in(current_currency).amount.present?
          @selected_variant = @variant_from_options = @product.master
        else
          @selected_variant = nil
          @variant_from_options = @product.master
        end
      end

      def product_has_only_one_secondary_option_type_value?
        return false unless product_option_types.size == 2
        return false unless product_option_types.first.color?

        @product.
          option_values.
          select { |ov| ov.option_type_id == product_option_types.last.id }.
          uniq(&:id).size == 1
      end

      def product_option_types
        @product_option_types ||= @product.option_types.to_a
      end
    end
  end
end
