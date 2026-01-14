module Spree
  module Api
    module V3
      class TaxonomySerializer < BaseSerializer
        attributes :id, :name

        # Conditional associations
        one :root,
            resource: Spree.api.v3_storefront_taxon_serializer,
            if: proc { params[:includes]&.include?('root') }

        many :taxons,
             resource: Spree.api.v3_storefront_taxon_serializer,
             if: proc { params[:includes]&.include?('taxons') }
      end
    end
  end
end
