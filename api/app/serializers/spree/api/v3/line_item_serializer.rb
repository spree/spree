module Spree
  module Api
    module V3
      class LineItemSerializer < BaseSerializer
        def attributes
          {
            id: resource.id,
            quantity: resource.quantity,
            price: resource.price.to_f,
            display_price: resource.display_price.to_s,

            total: resource.total.to_f,
            display_total: resource.display_total.to_s,

            adjustment_total: resource.adjustment_total.to_f,
            display_adjustment_total: resource.display_adjustment_total.to_s,

            promo_total: resource.promo_total.to_f,
            display_promo_total: resource.display_promo_total.to_s,

            included_tax_total: resource.included_tax_total.to_f,
            display_included_tax_total: resource.display_included_tax_total.to_s,

            additional_tax_total: resource.additional_tax_total.to_f,
            display_additional_tax_total: resource.display_additional_tax_total.to_s,

            pre_tax_amount: resource.pre_tax_amount.to_f,
            display_pre_tax_amount: resource.display_pre_tax_amount.to_s,

            compare_at_amount: resource.compare_at_amount.to_f,
            display_compare_at_amount: resource.display_compare_at_amount.to_s,

            discounted_amount: resource.discounted_amount.to_f,
            display_discounted_amount: resource.display_discounted_amount.to_s,

            name: resource.name,
            slug: resource.slug,
            options_text: resource.options_text,
            currency: resource.currency
          }

          # Conditionally include variant
          base_attrs[:variant] = serialize_variant if include?('variant')

          base_attrs
        end

        private

        def serialize_variant
          variant_serializer.new(resource.variant, nested_context('variant')).as_json if resource.variant
        end

        # Serializer dependencies
        def variant_serializer
          Spree::Api::Dependencies.v3_storefront_variant_serializer.constantize
        end
      end
    end
  end
end
