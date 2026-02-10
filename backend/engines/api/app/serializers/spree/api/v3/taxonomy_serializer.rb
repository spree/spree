module Spree
  module Api
    module V3
      class TaxonomySerializer < BaseSerializer
        typelize name: :string, position: :number, root_id: 'string | null'

        attributes :name, :position,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :root_id do |taxonomy|
          taxonomy.root&.prefix_id
        end

        # Conditional associations
        # Note: We pass empty includes to nested taxons to prevent infinite recursion
        one :root,
            resource: Spree.api.taxon_serializer,
            if: proc { params[:includes]&.include?('root') },
            params: { includes: [] }

        many :taxons,
             resource: Spree.api.taxon_serializer,
             if: proc { params[:includes]&.include?('taxons') },
             params: { includes: [] }

        many :public_metafields,
             key: :metafields,
             resource: Spree.api.metafield_serializer,
             if: proc { params[:includes]&.include?('metafields') }
      end
    end
  end
end
