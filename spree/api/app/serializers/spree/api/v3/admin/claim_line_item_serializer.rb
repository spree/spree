# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        class ClaimLineItemSerializer < V3::ClaimLineItemSerializer
          attributes created_at: :iso8601, updated_at: :iso8601

          expandable :one, :variant, :admin_variant_serializer
          expandable :one, :replacement_variant, :admin_variant_serializer
        end
      end
    end
  end
end
