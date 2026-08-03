# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        class ExchangeLineItemSerializer < V3::ExchangeLineItemSerializer
          attributes created_at: :iso8601, updated_at: :iso8601

          one :original_variant, resource: proc { Spree.api.admin_variant_serializer }, if: proc { expand?('original_variant') }
          one :new_variant, resource: proc { Spree.api.admin_variant_serializer }, if: proc { expand?('new_variant') }
        end
      end
    end
  end
end
