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
                   field_type: Spree::CustomField::FIELD_TYPE_TOKENS,
                   resource_type: [:string, comment: 'Shorthand of the resource the field attaches to, for example product, variant, order, customer or category. Discover the full list from the resource_types endpoint; extensions may register more.'],
                   storefront_visible: :boolean,
                   searchable: :boolean,
                   sortable: :boolean,
                   filter_key: :string

          attributes :namespace, :key, :label, :field_type, :storefront_visible,
                     :searchable, :sortable, :filter_key,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :resource_type do |definition|
            Spree::Base.polymorphic_api_type(definition.resource_type)
          end
        end
      end
    end
  end
end
