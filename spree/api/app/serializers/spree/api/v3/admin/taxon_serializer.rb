module Spree
  module Api
    module V3
      module Admin
        # Admin API Taxon Serializer
        # Full taxon data including admin-only fields
        class TaxonSerializer < V3::TaxonSerializer
          typelize lft: :number, rgt: :number,
                   hide_from_nav: :boolean, sort_order: :string, rules_match_policy: :string,
                   automatic: :boolean

          # Admin-only attributes
          attributes :lft, :rgt, :hide_from_nav, :sort_order, :rules_match_policy, :automatic

          # Override all nested associations to use admin serializers
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

          one :taxonomy,
              resource: Spree.api.admin_taxonomy_serializer,
              if: proc { expand?('taxonomy') }
        end
      end
    end
  end
end
