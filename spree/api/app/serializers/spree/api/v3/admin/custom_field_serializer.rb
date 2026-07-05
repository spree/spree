module Spree
  module Api
    module V3
      module Admin
        # Admin API Custom Field Serializer
        # Full custom field data including admin-only fields
        class CustomFieldSerializer < V3::CustomFieldSerializer
          typelize storefront_visible: :boolean,
                   custom_field_definition_id: :string

          attributes created_at: :iso8601, updated_at: :iso8601

          attribute :storefront_visible do |custom_field|
            custom_field.metafield_definition.available_on_front_end?
          end

          attribute :custom_field_definition_id do |custom_field|
            custom_field.metafield_definition.prefixed_id
          end
        end
      end
    end
  end
end
