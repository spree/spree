module Spree
  module Api
    module V3
      # Store API Price Serializer
      # Represents a resolved/calculated price for storefront display
      # Can represent either a calculated price (with price list resolution) or a base price
      class PriceSerializer < BaseSerializer
        typelize amount: 'number | null',
                 amount_in_cents: 'number | null',
                 display_amount: 'string | null',
                 compare_at_amount: 'number | null',
                 compare_at_amount_in_cents: 'number | null',
                 display_compare_at_amount: 'string | null',
                 currency: 'string | null',
                 price_list_id: 'string | null'

        attributes :amount, :amount_in_cents, :compare_at_amount,
                   :compare_at_amount_in_cents, :currency

        attribute :display_amount do |price|
          price.display_amount&.to_s
        end

        attribute :display_compare_at_amount do |price|
          price.display_compare_at_amount&.to_s
        end

        attribute :price_list_id do |price|
          next nil unless price&.price_list_id.present?

          price.price_list.prefix_id
        end
      end
    end
  end
end
