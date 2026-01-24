module Spree
  module Api
    module V3
      class TaxonomySerializer < BaseSerializer
        typelize_from Spree::Taxonomy

        attributes :id, :name, :position,
                   created_at: :iso8601, updated_at: :iso8601

        # Conditional associations
        one :root,
            resource: Spree.api.taxon_serializer,
            if: proc { params[:includes]&.include?('root') }

        many :taxons,
             resource: Spree.api.taxon_serializer,
             if: proc { params[:includes]&.include?('taxons') }
      end
    end
  end
end
