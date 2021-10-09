module Spree
  module Api
    module V2
      module Platform
        class ShippingCategoriesController < ResourceController
          private

          def model_class
            Spree::ShippingCategory
          end
        end
      end
    end
  end
end
