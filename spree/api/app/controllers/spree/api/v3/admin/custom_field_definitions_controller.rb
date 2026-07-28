module Spree
  module Api
    module V3
      module Admin
        # Schema-side metadata for custom fields. Definitions are per resource
        # *type* (every Spree::Product shares the same definitions), so this is
        # a flat top-level endpoint. Filter by `?resource_type=Spree::Product`
        # (or any other registered custom-field-bearing resource) to scope the
        # list to one parent type.
        class CustomFieldDefinitionsController < ResourceController
          scoped_resource :settings

          protected

          def model_class
            Spree::CustomFieldDefinition
          end

          def serializer_class
            Spree.api.admin_custom_field_definition_serializer
          end

          # `label`, `field_type`, `storefront_visible` are model-side aliases
          # (alias_attribute / accessors) on Spree::CustomFieldDefinition. The
          # API → DB column rename lands in 6.0 and this controller stays flat.
          def permitted_params
            params.permit(:namespace, :key, :label, :field_type,
                          :resource_type, :storefront_visible,
                          :searchable, :sortable)
          end
        end
      end
    end
  end
end
