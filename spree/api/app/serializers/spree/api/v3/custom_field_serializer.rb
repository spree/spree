module Spree
  module Api
    module V3
      # Store API Custom Field Serializer
      # Customer-facing custom field data (storefront-visible only)
      class CustomFieldSerializer < BaseSerializer
        typelize key: :string,
                 label: :string,
                 field_type: Spree::CustomField::FIELD_TYPE_TOKENS,
                 value: :any,
                 display_value: [:string, comment: 'The value as plain text to show: the chosen labels of a choice field, ' \
                                                   'rich text without its markup. Dates stay ISO 8601.']

        attributes :label, :field_type

        attribute :key, &:full_key
        attribute :value, &:serialize_value
        attribute :display_value, &:display_value
      end
    end
  end
end
