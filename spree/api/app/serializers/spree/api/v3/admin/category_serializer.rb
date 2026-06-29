module Spree
  module Api
    module V3
      module Admin
        # Admin API Category Serializer
        # Full category data including admin-only fields
        class CategorySerializer < V3::CategorySerializer
          typelize pretty_name: :string, lft: :number, rgt: :number, sort_order: :string,
                   metadata: 'Record<string, unknown>'

          # Admin-only attributes
          attributes :metadata, :pretty_name, :lft, :rgt, created_at: :iso8601, updated_at: :iso8601

          # Override inherited associations to use admin serializers
          one :parent,
              resource: proc { Spree.api.admin_category_serializer },
              if: proc { expand?('parent') }

          many :children,
               resource: proc { Spree.api.admin_category_serializer },
               if: proc { expand?('children') }

          many :ancestors,
               resource: proc { Spree.api.admin_category_serializer },
               if: proc { expand?('ancestors') }

          many :metafields,
               key: :custom_fields,
               resource: proc { Spree.api.admin_custom_field_serializer },
               if: proc { expand?('custom_fields') }
        end
      end
    end
  end
end
