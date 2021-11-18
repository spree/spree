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
        end
      end
    end
  end
end
