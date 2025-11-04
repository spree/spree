module Spree
  module Api
    module V3
      class WishedItemSerializer < BaseSerializer
        def attributes
          base_attrs = {
            id: resource.id,
            quantity: resource.quantity,
            created_at: timestamp(resource.created_at),
            updated_at: timestamp(resource.updated_at)
          }

          # Conditionally include variant
          base_attrs[:variant] = serialize_variant if include?('variant')

          base_attrs
        end

        private

        def serialize_variant
          variant_serializer.new(resource.variant, nested_context('variant')).as_json if resource.variant
        end

        # Serializer dependencies
        def variant_serializer
          Spree::Api::Dependencies.v3_storefront_variant_serializer.constantize
        end
      end
    end
  end
end
