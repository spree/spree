module Spree
  module Api
    module V3
      module Store
        class TaxonomiesController < Store::ResourceController
          protected

          def model_class
            Spree::Taxonomy
          end

          def serializer_class
            Spree.api.taxonomy_serializer
          end
        end
      end
    end
  end
end
