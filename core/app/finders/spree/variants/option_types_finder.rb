module Spree
  module Variants
    class OptionTypesFinder
      COLOR_TYPE = 'color'.freeze

      def initialize(variant_ids:)
        @variant_ids = variant_ids
      end

      def execute
        Spree::OptionType.includes(option_values: :variants).where(spree_variants: { id: variant_ids }).
          reorder('spree_option_types.position ASC, spree_option_values.position ASC').
          partition { |option_type| option_type.name.downcase == COLOR_TYPE }.flatten
      end

      private

      attr_reader :variant_ids
    end
  end
end
