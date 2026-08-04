# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        class ReturnLineItemSerializer < V3::ReturnLineItemSerializer
          attributes created_at: :iso8601, updated_at: :iso8601

          one :variant, resource: proc { Spree.api.admin_variant_serializer }, if: proc { expand?('variant') }
          one :line_item, resource: proc { Spree.api.admin_line_item_serializer }, if: proc { expand?('line_item') }
        end
      end
    end
  end
end
