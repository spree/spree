module Spree
  module Api
    module V3
      # Store API Metafield Serializer
      # Customer-facing metafield data (public metafields only)
      class MetafieldSerializer < BaseSerializer
        typelize key: :string, name: :string, type: :string, value: :any

        attributes :name, :type

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
