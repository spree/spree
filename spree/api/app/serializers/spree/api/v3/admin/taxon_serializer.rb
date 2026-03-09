module Spree
  module Api
    module V3
      module Admin
        # Admin API Taxon Serializer
        # Full taxon data including admin-only fields
        class TaxonSerializer < V3::TaxonSerializer
          typelize lft: :number, rgt: :number

          # Nested set columns for tree operations
          attributes :lft, :rgt

          # Override inherited associations to use admin serializers
          one :parent,
              resource: Spree.api.admin_taxon_serializer,
              if: proc { expand?('parent') }

          many :children,
               resource: Spree.api.admin_taxon_serializer,
               if: proc { expand?('children') }

          many :ancestors,
               resource: Spree.api.admin_taxon_serializer,
               if: proc { expand?('ancestors') }

          many :metafields,
               resource: Spree.api.admin_metafield_serializer,
               if: proc { expand?('metafields') }
        end
      end
    end
  end
end
