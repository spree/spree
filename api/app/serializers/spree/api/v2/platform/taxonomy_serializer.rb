module Spree
  module Api
    module V2
      module Platform
        class TaxonomySerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :taxons
          has_one :root, serializer: :taxon
        end
      end
    end
  end
end
