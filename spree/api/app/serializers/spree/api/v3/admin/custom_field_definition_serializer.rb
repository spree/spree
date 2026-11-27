module Spree
  module Api
    module V3
      module Admin
        # Admin API Custom Field Definition Serializer
        # Schema-side metadata for custom fields (per resource type).
        class CustomFieldDefinitionSerializer < V3::CustomFieldDefinitionSerializer
          typelize resource_type: [:string, comment: 'Shorthand of the resource the field attaches to, for example product, variant, ' \
                                                     'order, customer or category. Discover the full list from the resource_types ' \
                                                     'endpoint; extensions may register more.'],
                   storefront_visible: :boolean,
                   storefront_writable: [:boolean, comment: 'Shoppers fill the field in: an order field at checkout, a customer field ' \
                                                            'at registration and from their account.'],
                   searchable: :boolean,
                   sortable: :boolean,
                   filter_key: :string

          attributes :storefront_visible, :storefront_writable, :searchable, :sortable, :filter_key,
                     created_at: :iso8601, updated_at: :iso8601

          one :validations, source: proc { self }, resource: proc { Spree.api.admin_custom_field_validations_serializer }
        end
      end
    end
  end
end
