module Spree
  module Api
    module V3
      module Admin
        # Schema-side metadata for custom fields. Definitions are per resource
        # *type* (every Spree::Product shares the same definitions), so this is
        # a flat top-level endpoint. Filter by `q[resource_type_eq]=product`
        # (or any other registered custom-field-bearing resource) to scope the
        # list to one parent type.
        class CustomFieldDefinitionsController < ResourceController
          scoped_resource :settings

          request_params :custom_field_definition do |body|
            body.attribute :namespace, :string, description: 'Defaults to `custom`.'
            body.attribute :key, :string, required: true, on: :create
            body.attribute :label, :string, description: 'Human-readable name; defaults to the titleized `key`.'
            body.attribute :field_type, :string,
              required: true, on: :create,
              example: 'short_text',
              description: 'Custom field type token (`short_text`, `long_text`, `rich_text`, `number`, …). An extension type that has no token is named by its registered class instead.'
            body.attribute :resource_type, :string,
              required: true, on: :create,
              example: 'product',
              description: 'Shorthand of the resource the field attaches to, from the resource types endpoint.'
            body.attribute :storefront_visible, :boolean,
              description: 'When false, the definition is admin-only and never exposed in the Store API.'
            body.attribute :searchable, :boolean,
              description: 'Include values in storefront product text search. Supported for `short_text`, `long_text` and `number` fields; other types are refused.'
            body.attribute :sortable, :boolean,
              description: 'Allow storefront product listings to sort by this field (`sort=cf_{namespace}_{key}`). Supported for `short_text` and `number` fields; other types are refused.'
          end

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
            params.permit(*permitted_attributes)
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
