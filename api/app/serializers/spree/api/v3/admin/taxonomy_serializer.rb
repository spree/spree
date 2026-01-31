module Spree
  module Api
    module V3
      module Admin
        # Admin API Taxonomy Serializer
        # Full taxonomy data including admin-only fields
        class TaxonomySerializer < V3::TaxonomySerializer
          many :metafields,
               resource: Spree::Api::V3::Admin::MetafieldSerializer,
               if: proc { params[:includes]&.include?('metafields') }
        end
      end
    end
  end
end
