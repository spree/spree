module Spree
  module Api
    module V3
      module Admin
        class ProductTypeSerializer < V3::ProductTypeSerializer
          include Spree::Api::V3::Admin::Translatable

          typelize fulfillment_types: [:string, multi: true],
                   products_count: :number,
                   option_type_ids: [:string, multi: true],
                   category_ids: [:string, multi: true]

          attributes :fulfillment_types, :products_count,
                     created_at: :iso8601, updated_at: :iso8601

          # Prefixed ids of the option types and categories this type seeds onto
          # new products — the same payload the client sends back on PATCH.
          attribute :option_type_ids, &:option_type_prefixed_ids
          attribute :category_ids, &:category_prefixed_ids

          many :product_type_custom_field_definitions,
               key: :custom_field_definitions,
               resource: proc { Spree.api.admin_product_type_custom_field_definition_serializer }
        end
      end
    end
  end
end
