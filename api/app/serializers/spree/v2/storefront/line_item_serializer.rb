module Spree
  module V2
    module Storefront
      class LineItemSerializer < BaseSerializer
        set_type   :line_item

        attributes :name, :quantity, :price, :slug, :options_text, :currency,
                   :display_price, :total, :display_total, :adjustment_total,
                   :display_adjustment_total, :additional_tax_total,
                   :discounted_amount, :display_discounted_amount,
                   :display_additional_tax_total, :promo_total, :display_promo_total,
                   :included_tax_total, :display_included_tax_total,
                   :pre_tax_amount, :display_pre_tax_amount, :compare_at_amount, :display_compare_at_amount,
                   :public_metadata

        belongs_to :variant, serializer: Spree::Api::Dependencies.storefront_variant_serializer.constantize
        has_many :digital_links, serializer: Spree::Api::Dependencies.storefront_digital_link_serializer.constantize
      end
    end
  end
end
