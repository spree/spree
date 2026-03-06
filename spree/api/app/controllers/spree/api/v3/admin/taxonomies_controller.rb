module Spree
  module Api
    module V3
      module Admin
        class TaxonomiesController < ResourceController
          protected

          def model_class
            Spree::Taxonomy
          end

          def serializer_class
            Spree.api.admin_taxonomy_serializer
          end
        end
      end
    end
  end
end
