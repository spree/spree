# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        class ExchangeLineItemSerializer < V3::ExchangeLineItemSerializer
          attributes created_at: :iso8601, updated_at: :iso8601

          expandable :one, :original_variant, :admin_variant_serializer
          expandable :one, :new_variant, :admin_variant_serializer
        end
      end
    end
  end
end
