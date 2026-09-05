# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Seller
        # One line of a claim — what went wrong, and what is being sent or
        # refunded to put it right.
        class ClaimLineItemSerializer < V3::ClaimLineItemSerializer
          typelize name: [:string, nullable: true]

          attribute :name do |line|
            line.line_item&.name || line.variant&.name
          end

          one :variant, resource: proc { Spree.api.seller_variant_serializer }, if: proc { expand?('variant') }
        end
      end
    end
  end
end
