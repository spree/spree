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

          def resource_serializer
            Spree::Api::Dependencies.platform_tax_category_serializer.constantize
          end
        end
      end
    end
  end
end
