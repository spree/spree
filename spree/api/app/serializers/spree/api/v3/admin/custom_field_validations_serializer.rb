module Spree
  module Api
    module V3
      module Admin
        class CustomFieldValidationsSerializer < BaseSerializer
          _attributes.delete(:id)

          typelize required: :boolean,
                   min: ['number | string | null',
                         comment: 'Characters for text fields, a value for number fields, an ISO 8601 date or date-time for date fields.'],
                   max: ['number | string | null',
                         comment: 'Characters for text fields, a value for number fields, an ISO 8601 date or date-time for date fields.'],
                   multiple: :boolean,
                   choices: [:CustomFieldChoice, multi: true]

          attribute :required, &:required?
          attribute :min do |definition|
            definition.validation_rules['min']
          end
          attribute :max do |definition|
            definition.validation_rules['max']
          end
          attribute :multiple, &:multiple_choices?

          many :choices, resource: proc { Spree.api.admin_custom_field_choice_serializer }
        end
      end
    end
  end
end
