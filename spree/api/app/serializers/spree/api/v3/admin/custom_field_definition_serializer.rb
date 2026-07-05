module Spree
  module Api
    module V3
      module Admin
        # Admin API Custom Field Definition Serializer
        # Schema-side metadata for custom fields (per resource type).
        class CustomFieldDefinitionSerializer < BaseSerializer
          typelize namespace: :string,
                   key: :string,
                   label: :string,
                   field_type: Spree::Metafield::FIELD_TYPE_TOKENS,
                   resource_type: :string,
                   storefront_visible: :boolean

          attributes :namespace, :key, :label, :field_type, :resource_type, :storefront_visible,
                     created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
