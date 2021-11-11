module Spree
  module Api
    module V2
      module Platform
        class TaxonomiesController < ResourceController
          private

          def model_class
            Spree::Taxonomy
          end
        end
      end
    end
  end
end
