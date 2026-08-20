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

          # GET /api/v3/admin/custom_field_definitions/resource_types
          #
          # What a definition can be attached to, from
          # `Spree.custom_fields.enabled_resources` — so a resource an
          # extension registers is offered without the dashboard shipping a
          # new list, and a merchant is never shown a type the server would
          # then refuse.
          def resource_types
            authorize! :create, model_class

            render json: { data: Spree::CustomFieldDefinition.enabled_resource_types }
          end

          protected

          def model_class
            Spree::CustomFieldDefinition
          end

          def serializer_class
            Spree.api.admin_custom_field_definition_serializer
          end

          def permitted_params
            params.permit(*model_additional_permitted_attributes, :namespace, :key, :label, :field_type,
                          :resource_type, :storefront_visible,
                          :searchable, :sortable)
          end

          # Pure registry discovery — maps to the read scope.
          def read_actions
            super + %w[resource_types]
          end
        end
      end
    end
  end
end
