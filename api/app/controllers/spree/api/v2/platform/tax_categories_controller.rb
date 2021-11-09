module Spree
  module Api
    module V2
      module Platform
        class TaxCategoriesController < ResourceController
          private

          def model_class
            Spree::TaxCategory
          end

          def scope_includes
            [:tax_rates]
          end
        end
      end
    end
  end
end
