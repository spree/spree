module Spree
  module Api
    module V3
      module Store
        # The custom fields a shopper fills in: an order's at checkout, a
        # customer's at registration and from their account. Storefronts render
        # their forms from this list, with each field's type, label and rules.
        # Filter it with `q[resource_type_eq]=order` or `customer`.
        class CustomFieldDefinitionsController < Store::ResourceController
          include Spree::Api::V3::HttpCaching

          protected

          def model_class
            Spree::CustomFieldDefinition
          end

          def serializer_class
            Spree.api.custom_field_definition_serializer
          end

          # Writable fields are always storefront visible, so nothing admin-only is reachable from here.
          def scope
            super.storefront_writable.storefront_visible.order(:resource_type, :namespace, :key)
          end
        end
      end
    end
  end
end
