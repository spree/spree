module Spree
  module Api
    module V2
      module Platform
        class TaxonomiesController < ResourceController
          private

          def model_class
            Spree::Taxonomy
          end

          def scope_includes
            [:taxons, :root]
          end

          def resource_serializer
            Spree::Api::Dependencies.platform_taxonomy_serializer.constantize
          end
        end
      end
    end
  end
end
