module Spree
  module Api
    module V3
      # Store API Custom Field Serializer
      # Customer-facing custom field data (storefront-visible only)
      class CustomFieldSerializer < BaseSerializer
        typelize key: :string,
                 label: :string,
                 field_type: Spree::CustomField::FIELD_TYPE_TOKENS,
                 value: :any

        attributes :label, :field_type

        attribute :key, &:full_key
        attribute :value, &:serialize_value
      end
    end
  end
end
