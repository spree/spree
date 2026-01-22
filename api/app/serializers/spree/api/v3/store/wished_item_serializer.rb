module Spree
  module Api
    module V3
      module Store
        class WishedItemSerializer < BaseSerializer
          attributes :id, :variant_id, :wishlist_id, :quantity

          one :variant, resource: Spree.api.v3_store_variant_serializer
        end
      end
    end
  end
end
