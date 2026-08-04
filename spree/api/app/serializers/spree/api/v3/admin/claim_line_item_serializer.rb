# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        class ClaimLineItemSerializer < V3::ClaimLineItemSerializer
          attributes created_at: :iso8601, updated_at: :iso8601

          one :variant, resource: proc { Spree.api.admin_variant_serializer }, if: proc { expand?('variant') }
          one :replacement_variant, resource: proc { Spree.api.admin_variant_serializer }, if: proc { expand?('replacement_variant') }
        end
      end
    end
  end
end
