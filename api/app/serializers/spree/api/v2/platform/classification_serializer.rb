module Spree
  module Api
    module V2
      module Platform
        class ClassificationSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :product, serializer: Spree::Api::Dependencies.platform_product_serializer.constantize
          belongs_to :taxon, serializer: Spree::Api::Dependencies.platform_taxon_serializer.constantize
        end
      end
    end
  end
end
