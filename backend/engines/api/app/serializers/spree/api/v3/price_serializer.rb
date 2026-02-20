module Spree
  module Api
    module V3
      # Store API Price Serializer
      # Represents a resolved/calculated price for storefront display
      # Can represent either a calculated price (with price list resolution) or a base price
      class PriceSerializer < BaseSerializer
        typelize amount: [:string, nullable: true],
                 amount_in_cents: [:number, nullable: true],
                 display_amount: [:string, nullable: true],
                 compare_at_amount: [:string, nullable: true],
                 compare_at_amount_in_cents: [:number, nullable: true],
                 display_compare_at_amount: [:string, nullable: true],
                 currency: [:string, nullable: true],
                 price_list_id: [:string, nullable: true]

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

          price.price_list.prefixed_id
        end
      end
    end
  end
end
