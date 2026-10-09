# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        class ClaimLineItemSerializer < V3::ClaimLineItemSerializer
          # No guest price gating here, so the inherited money fields are always present.
          typelize refund_amount: [:string, nullable: false], paid_amount: [:string, nullable: false],
                   pre_tax_amount: [:string, nullable: false], included_tax_total: [:string, nullable: false],
                   additional_tax_total: [:string, nullable: false], tax_total: [:string, nullable: false],
                   display_refund_amount: [:string, nullable: false]

          attributes created_at: :iso8601, updated_at: :iso8601

          one :variant, resource: proc { Spree.api.admin_variant_serializer }, if: proc { expand?('variant') }
          one :replacement_variant, resource: proc { Spree.api.admin_variant_serializer }, if: proc { expand?('replacement_variant') }
        end
      end
    end
  end
end
