module Spree
  module Api
    module V3
      class WishlistSerializer < BaseSerializer
        def attributes
          {
            id: resource.id,
            name: resource.name,
            is_default: resource.is_default?,
            is_private: resource.is_private?,
            token: resource.token,
            created_at: timestamp(resource.created_at),
            updated_at: timestamp(resource.updated_at)
          }

          # Conditionally include items
          base_attrs[:items] = serialize_items if include?('items')

          base_attrs
        end

        private

        def serialize_items
          resource.wished_items.map do |item|
            wished_item_serializer.new(item, nested_context('items')).as_json
          end
        end

        # Serializer dependencies
        def wished_item_serializer
          Spree::Api::Dependencies.v3_storefront_wished_item_serializer.constantize
        end
      end
    end
  end
end
