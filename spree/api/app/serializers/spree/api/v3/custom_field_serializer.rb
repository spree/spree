module Spree
  module Api
    module V3
      # Store API Custom Field Serializer
      # Customer-facing custom field data (public metafields only)
      class CustomFieldSerializer < BaseSerializer
        typelize key: :string, label: :string, type: :string, value: :any

        attributes :label, :type

        attribute :key do |metafield|
          metafield.full_key
        end

        attribute :value do |metafield|
          metafield.serialize_value
        end
      end
    end
  end
end
