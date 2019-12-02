module Spree
  module Variants
    class OptionTypesPresenter
      def initialize(option_types)
        @option_types = option_types
      end

      def default_variant
        default_variant_data[:variant]
      end

      def options
        option_types.map do |option_type|
          {
            id: option_type.id,
            name: option_type.name,
            presentation: option_type.presentation,
            position: option_type.position,
            option_values: option_values_options(option_type.option_values)
          }
        end
      end

      private

      attr_reader :option_types

      def default_variant_data
        return {} if option_types.empty?

        @default_variant_data ||= begin
          find_in_stock_variant_data || find_backorderable_variant_data || find_first_variant_data
        end
      end

      def find_in_stock_variant_data
        find_variant_data(&:in_stock?)
      end

      def find_backorderable_variant_data
        find_variant_data(&:backorderable?)
      end

      def find_variant_data(&block)
        option_types.first.option_values.each do |option_value|
          variant = option_value.variants.find(&block)

          return { variant: variant, option_value: option_value } if variant
        end

        nil
      end

      def find_first_variant_data
        option_value = option_types.first.option_values.first
        variant = option_value.variants.first

        { variant: variant, option_value: option_value }
      end

      def option_values_options(option_values)
        option_values.map do |option_value|
          {
            id: option_value.id,
            position: option_value.position,
            presentation: option_value.presentation,
            variant_id: option_value.variants.first.id,
            is_default: option_value == default_variant_data[:option_value]
          }
        end
      end
    end
  end
end
