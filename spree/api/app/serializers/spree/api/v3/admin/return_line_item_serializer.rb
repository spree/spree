# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        class ReturnLineItemSerializer < V3::ReturnLineItemSerializer
          attributes created_at: :iso8601, updated_at: :iso8601

          expandable :one, :variant, :admin_variant_serializer
          expandable :one, :line_item, :admin_line_item_serializer
          expandable :many, :tax_lines, :admin_tax_line_serializer
        end
      end
    end
  end
end
