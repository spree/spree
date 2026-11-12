# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        class ExchangeLineItemSerializer < V3::ExchangeLineItemSerializer
          # No guest price gating here, so the inherited money fields are always present.
          typelize original_price: [:string, nullable: false], new_variant_price: [:string, nullable: false],
                   price_difference: [:string, nullable: false], original_tax_total: [:string, nullable: false],
                   new_tax_total: [:string, nullable: false]

          attributes created_at: :iso8601, updated_at: :iso8601

          one :original_variant, resource: proc { Spree.api.admin_variant_serializer }, if: proc { expand?('original_variant') }
          one :new_variant, resource: proc { Spree.api.admin_variant_serializer }, if: proc { expand?('new_variant') }
        end
      end
    end
  end
end
