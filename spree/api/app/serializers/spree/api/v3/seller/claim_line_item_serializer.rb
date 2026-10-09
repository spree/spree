# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Seller
        # One line of a claim — what went wrong, and what is being sent or
        # refunded to put it right.
        class ClaimLineItemSerializer < V3::ClaimLineItemSerializer
          # No guest price gating here, so the inherited money fields are always present.
          typelize refund_amount: [:string, nullable: false], paid_amount: [:string, nullable: false],
                   pre_tax_amount: [:string, nullable: false], included_tax_total: [:string, nullable: false],
                   additional_tax_total: [:string, nullable: false], tax_total: [:string, nullable: false],
                   display_refund_amount: [:string, nullable: false]

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
