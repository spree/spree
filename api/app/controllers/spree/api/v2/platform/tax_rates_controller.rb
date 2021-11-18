module Spree
  module Api
    module V2
      module Platform
        class TaxRatesController < ResourceController
          private

          def model_class
            Spree::TaxRate
          end

          def scope_includes
            [:zone, :tax_category]
          end

          def spree_permitted_attributes
            super + [calculator_attributes: Spree::Calculator.json_api_permitted_attributes]
          end
        end
      end
    end
  end
end
