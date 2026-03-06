module Spree
  module Api
    module V3
      module Admin
        # Admin API Taxonomy Serializer
        # Full taxonomy data including admin-only fields
        class TaxonomySerializer < V3::TaxonomySerializer
          many :metafields,
               resource: Spree.api.admin_metafield_serializer,
               if: proc { expand?('metafields') }
        end
      end
    end
  end
end
