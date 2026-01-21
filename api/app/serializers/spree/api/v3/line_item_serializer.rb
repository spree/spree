module Spree
  module Api
    module V3
      class LineItemSerializer < BaseSerializer
        attributes :id, :variant_id, :quantity, :name, :slug, :options_text,
                   :price, :display_price, :total, :display_total,
                   :adjustment_total, :display_adjustment_total,
                   :additional_tax_total, :display_additional_tax_total,
                   :included_tax_total, :display_included_tax_total,
                   :promo_total, :display_promo_total,
                   :pre_tax_amount, :display_pre_tax_amount,
                   :discounted_amount, :display_discounted_amount,
                   :compare_at_amount, :display_compare_at_amount

        many :images, resource: Spree.api.v3_storefront_image_serializer
        many :option_values, resource: Spree.api.v3_storefront_option_value_serializer
      end
    end
  end
end
