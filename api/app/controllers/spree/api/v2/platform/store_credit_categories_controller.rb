module Spree
  module Api
    module V2
      module Platform
        class StoreCreditCategoriesController < ResourceController
          private

          def model_class
            Spree::StoreCreditCategory
          end
        end
      end
    end
  end
end
