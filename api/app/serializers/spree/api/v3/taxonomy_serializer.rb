module Spree
  module Api
    module V3
      class TaxonomySerializer < BaseSerializer
        typelize name: :string, position: :number

        attributes :name, :position,
                   created_at: :iso8601, updated_at: :iso8601

        # Conditional associations
        one :root,
            resource: Spree.api.taxon_serializer,
            if: proc { params[:includes]&.include?('root') }

        many :taxons,
             resource: Spree.api.taxon_serializer,
             if: proc { params[:includes]&.include?('taxons') }

        many :public_metafields,
             key: :metafields,
             resource: Spree.api.metafield_serializer,
             if: proc { params[:includes]&.include?('metafields') }
      end
    end
  end
end
