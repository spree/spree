module Spree
  module Api
    module V3
      class WishedItemSerializer < BaseSerializer
        typelize_from Spree::WishedItem

        attributes :id, :variant_id, :wishlist_id, :quantity,
                   created_at: :iso8601, updated_at: :iso8601

        one :variant, resource: Spree.api.variant_serializer
      end
    end
  end
end
