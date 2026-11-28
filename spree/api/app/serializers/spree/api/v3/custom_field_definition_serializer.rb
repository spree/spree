module Spree
  module Api
    module V3
      # A custom field a shopper fills in: its type, label and rules.
      class CustomFieldDefinitionSerializer < BaseSerializer
        typelize namespace: :string,
                 key: :string,
                 full_key: [:string, comment: 'The `namespace.key` a value is read and written under.'],
                 label: :string,
                 field_type: Spree::CustomField::FIELD_TYPE_TOKENS,
                 resource_type: [:string, comment: 'Shorthand of the resource the field attaches to: order or customer on the Store API.'],
                 validations: :CustomFieldValidations

        attributes :namespace, :key, :full_key, :label, :field_type

        attribute :resource_type do |definition|
          Spree::Base.polymorphic_api_type(definition.resource_type)
        end

        one :validations, source: proc { self }, resource: proc { Spree.api.custom_field_validations_serializer }
      end
    end
  end
end
