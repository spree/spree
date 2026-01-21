module Spree
  module Api
    module V3
      class WishedItemSerializer < BaseSerializer
        attributes :id, :variant_id, :wishlist_id, :quantity, created_at: :iso8601, updated_at: :iso8601

        one :variant,
            resource: Spree.api.v3_storefront_variant_serializer,
            if: proc { params[:includes]&.include?('variant') }
      end
    end
  end
end
