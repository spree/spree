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
                   :included_tax_total, :display_included_tax_total

        belongs_to :variant
      end
    end
  end
end
