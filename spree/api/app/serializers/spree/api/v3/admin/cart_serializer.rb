# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        # Admin Cart serializer — the store shape plus operational timestamps,
        # slimmed to what inspecting an originating cart needs. The cart's
        # fulfillment/payment sub-graphs are pre-conversion duplicates of the
        # order's own and are dropped (they also ballooned the generated type
        # graph past the TypeScript instantiation limit). Kept associations
        # are redeclared with admin counterparts — admin serializers never
        # reference store serializers.
        class CartSerializer < V3::CartSerializer
          %i[fulfillments payments payment_methods gift_card discounts].each { |key| _attributes.delete(key) }

          typelize completed_at: [:string, nullable: true]

          attributes completed_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

          many :order_promotions, key: :applied_promotions, resource: proc { Spree.api.admin_applied_promotion_serializer }
          many :line_items, key: :items, resource: proc { Spree.api.admin_line_item_serializer }
          one :billing_address, resource: proc { Spree.api.admin_address_serializer }
          one :shipping_address, resource: proc { Spree.api.admin_address_serializer }
          one :market, resource: proc { Spree.api.admin_market_serializer }
        end
      end
    end
  end
end
