module Spree
  module Api
    module V3
      # Store API Custom Field Serializer
      # Customer-facing custom field data (storefront-visible only)
      class CustomFieldSerializer < BaseSerializer
        typelize key: :string,
                 label: :string,
                 type: [:string, deprecated: 'Use `field_type` instead. The legacy `type` field returns the Ruby STI class name (e.g. `Spree::Metafields::ShortText`) and will be removed in a future minor.'],
                 field_type: Spree::Metafield::FIELD_TYPE_TOKENS,
                 value: :any

        attributes :label, :type, :field_type

        attribute :key, &:full_key
        attribute :value, &:serialize_value
      end
    end
  end
end
