module Spree
  module Api
    module V2
      module Platform
        class TaxonomySerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :taxons, serializer: Spree.api.platform_taxon_serializer
          has_one :root, serializer: Spree.api.platform_taxon_serializer
        end
      end
    end
  end
end
