module Spree
  module Api
    module V3
      module Admin
        # Admin API Taxon Serializer
        # Full taxon data including admin-only fields
        class TaxonSerializer < V3::TaxonSerializer
          many :metafields,
               resource: Spree::Api::V3::Admin::MetafieldSerializer,
               if: proc { params[:includes]&.include?('metafields') }
        end
      end
    end
  end
end
