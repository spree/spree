module Spree
  module Api
    module V2
      module Platform
        class TaxonomySerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :taxons, serializer: Spree::Api::Dependencies.platform_taxon_serializer.constantize
          has_one :root, serializer: Spree::Api::Dependencies.platform_taxon_serializer.constantize
        end
      end
    end
  end
end
