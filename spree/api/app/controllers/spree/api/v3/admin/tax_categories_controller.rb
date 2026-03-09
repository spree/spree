module Spree
  module Api
    module V3
      module Admin
        class TaxCategoriesController < ResourceController
          protected

          def model_class
            Spree::TaxCategory
          end

          def serializer_class
            Spree.api.admin_tax_category_serializer
          end
        end
      end
    end
  end
end
