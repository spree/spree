module Spree
  module Api
    module V3
      # Store API Price Serializer
      # Represents a resolved/calculated price for storefront display
      # Can represent either a calculated price (with price list resolution) or a base price
      class PriceSerializer < BaseSerializer
        typelize display_amount: [:string, nullable: true],
                 display_compare_at_amount: [:string, nullable: true],
                 currency: [:string, nullable: true],
                 price_list_id: [:string, nullable: true]

        attributes :currency

        money_attributes :amount, :compare_at_amount, unit_price: true

        attribute :display_amount do |price|
          price.display_amount&.to_s
        end

        attribute :display_compare_at_amount do |price|
          price.display_compare_at_amount&.to_s
        end

        prefixed_id_attributes :price_list
      end
    end
  end
end
