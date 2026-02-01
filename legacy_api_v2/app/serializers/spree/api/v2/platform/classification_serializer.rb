module Spree
  module Api
    module V2
      module Platform
        class ClassificationSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :product, serializer: Spree.api.platform_product_serializer
          belongs_to :taxon, serializer: Spree.api.platform_taxon_serializer
        end
      end
    end
  end
end
