module Spree
  module ReturnItem::ExchangeVariantEligibility
    class SameOptionValue
      class_attribute :option_type_restrictions
      self.option_type_restrictions = []
      # This can be configured in an initializer, e.g.:
      # Spree::ReturnItem::ExchangeVariantEligibility::SameOptionValue.option_type_restrictions = ["size", "color"]
      #
      # This restriction causes only variants that share the same option value for the
      # specified option types to be returned. e.g.:
      #
      # option_type_restrictions = ["color", "waist"]
      # Variant: blue pants with 32 waist and 30 inseam
      #
      # can be exchanged for:
      # blue pants with 32 waist and 31 inseam
      #
      # cannot be exchanged for:
      # green pants with 32 waist and 30 inseam
      # blue pants with 34 waist and 32 inseam

      def self.eligible_variants(variant)
        product_variants = SameProduct.eligible_variants(variant).includes(option_values: :option_type)

        relevant_option_values = variant.option_values.select { |ov| option_type_restrictions.include? ov.option_type.name }
        if relevant_option_values.present?
          product_variants.select { |v| (relevant_option_values & v.option_values) == relevant_option_values }
        else
          product_variants
        end
      end
    end
  end
end
