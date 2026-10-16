# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Seller
        # One line of an exchange — what came back and what goes out in its
        # place. Both variants expand through the seller's own serializer.
        class ExchangeLineItemSerializer < V3::ExchangeLineItemSerializer
          # No guest price gating here, so the inherited money fields are always present.
          typelize original_price: [:string, nullable: false], new_variant_price: [:string, nullable: false],
                   price_difference: [:string, nullable: false], original_tax_total: [:string, nullable: false],
                   new_tax_total: [:string, nullable: false]

          typelize name: [:string, nullable: true],
                   new_variant_name: [:string, nullable: true]

          attribute :name do |line|
            line.line_item&.name || line.original_variant&.name
          end

          attribute :new_variant_name do |line|
            line.new_variant&.name
          end

          one :original_variant, resource: proc { Spree.api.seller_variant_serializer },
                                 if: proc { expand?('original_variant') }
          one :new_variant, resource: proc { Spree.api.seller_variant_serializer },
                            if: proc { expand?('new_variant') }
        end
      end
    end
  end
end
