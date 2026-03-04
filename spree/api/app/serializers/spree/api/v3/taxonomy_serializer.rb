module Spree
  module Api
    module V3
      class TaxonomySerializer < BaseSerializer
        typelize name: :string, position: :number, root_id: [:string, nullable: true]

        attributes :name, :position,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :root_id do |taxonomy|
          taxonomy.root&.prefixed_id
        end

        # Conditional associations
        # Note: We pass empty expand to nested taxons to prevent infinite recursion
        one :root,
            resource: Spree.api.taxon_serializer,
            if: proc { params[:expand]&.include?('root') },
            params: { expand: [] }

        many :taxons,
             resource: Spree.api.taxon_serializer,
             if: proc { params[:expand]&.include?('taxons') },
             params: { expand: [] }

        many :public_metafields,
             key: :metafields,
             resource: Spree.api.metafield_serializer,
             if: proc { params[:expand]&.include?('metafields') }
      end
    end
  end
end
