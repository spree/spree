module Spree
  module Api
    module V3
      module Store
        class TaxonomySerializer < BaseSerializer
          attributes :id, :name, :position

          # Conditional associations
          one :root,
              resource: Spree.api.v3_store_taxon_serializer,
              if: proc { params[:includes]&.include?('root') }

          many :taxons,
              resource: Spree.api.v3_store_taxon_serializer,
              if: proc { params[:includes]&.include?('taxons') }
          end
      end
    end
  end
end
