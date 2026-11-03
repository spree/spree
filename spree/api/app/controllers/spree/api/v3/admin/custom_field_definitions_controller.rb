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
              required: true, on: :create, only: :create,
              example: 'short_text',
              description: 'Custom field type token (`short_text`, `long_text`, `rich_text`, `number`, `boolean`, `json`, `date`, `date_time`, `choice`). An extension type that has no token is named by its registered class instead. Fixed once the definition is created.'
            body.attribute :resource_type, :string,
              required: true, on: :create, only: :create,
              example: 'product',
              description: 'Shorthand of the resource the field attaches to, from the resource types endpoint. Fixed once the definition is created.'
            body.attribute :storefront_visible, :boolean,
              description: 'When false, the definition is admin-only and never exposed in the Store API. Defaults to false.'
            body.attribute :searchable, :boolean,
              description: 'Include values in storefront product text search. Supported for `short_text`, `long_text`, `number`, `date`, `date_time` and `choice` fields; other types are refused.'
            body.attribute :sortable, :boolean,
              description: 'Allow storefront product listings to sort by this field (`sort=cf_{namespace}_{key}`). Supported for `short_text`, `number`, `date`, `date_time` and single `choice` fields; other types are refused.'
            body.attribute :validations, :object, nullable: true, as: 'CustomFieldValidationsParams',
              description: 'Rules for the values. Each applies only to the field types it names; values are checked when written, so existing values stay readable after a rule changes. Replaces the stored rules; send null to remove every rule.' do |rules|
              rules.attribute :required, :boolean,
                description: 'The value cannot be blank. Marked and checked by the forms that edit the value; the API accepts a blank value.'
              rules.attribute :min, :any,
                description: 'Inclusive lower bound: a character count for `short_text` and `long_text`, a number for `number`, an ISO 8601 date or date-time for `date` and `date_time`.'
              rules.attribute :max, :any,
                description: 'Inclusive upper bound, in the same form as `min`.'
              rules.attribute :choices, :array, as: 'CustomFieldChoiceParams',
                description: 'For `choice` fields, required: the options in display order. Values must be unique.' do |choice|
                choice.attribute :value, :string, required: true, description: 'What is stored.'
                choice.attribute :label, :string, description: 'What is shown; defaults to the value.'
              end
              rules.attribute :multiple, :boolean,
                description: 'For `choice` fields: several values may be chosen, and the value is a list.'
            end
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

          # Both types are create-only, so the update body leaves them out. A
          # client that still sends one gets the model's 422 rather than having
          # it dropped silently and believing the type changed.
          def permitted_params
            permitted = params.permit(*permitted_attributes)
            # `permit` drops a null object, and null is how rules are removed.
            permitted[:validations] = nil if params.key?(:validations) && params[:validations].nil?
            action_name == 'update' ? permitted.merge(params.permit(:field_type, :resource_type)) : permitted
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
