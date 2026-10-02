module Spree
  module Api
    module V3
      module Admin
        # Admin API Category Serializer
        # Full category data including admin-only fields
        class CategorySerializer < V3::CategorySerializer
          include Concerns::ExternalReferencesAttribute

          include Spree::Api::V3::Admin::Translatable

          typelize pretty_name: :string, lft: :number, rgt: :number, products_count: :number,
                   metadata: 'Record<string, unknown>'

          attributes :metadata, :pretty_name, :lft, :rgt, :products_count,
                     created_at: :iso8601, updated_at: :iso8601

          # Override inherited associations to use admin serializers
          expandable :one, :parent, :admin_category_serializer

          expandable :many, :children, :admin_category_serializer

          expandable :many, :ancestors, :admin_category_serializer

          expandable :many, :custom_fields, :admin_custom_field_serializer
        end
      end
    end
  end
end
