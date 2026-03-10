module Spree
  module Api
    module V3
      module Admin
        # Admin API Category Serializer
        # Full category data including admin-only fields
        class CategorySerializer < V3::CategorySerializer
          typelize lft: :number, rgt: :number

          # Nested set columns for tree operations
          attributes :lft, :rgt

          # Override inherited associations to use admin serializers
          one :parent,
              resource: Spree.api.admin_category_serializer,
              if: proc { expand?('parent') }

          many :children,
               resource: Spree.api.admin_category_serializer,
               if: proc { expand?('children') }

          many :ancestors,
               resource: Spree.api.admin_category_serializer,
               if: proc { expand?('ancestors') }

          many :metafields,
               resource: Spree.api.admin_metafield_serializer,
               if: proc { expand?('metafields') }
        end
      end
    end
  end
end
