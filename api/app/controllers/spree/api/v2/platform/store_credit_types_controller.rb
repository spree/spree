module Spree
  module Api
    module V2
      module Platform
        class StoreCreditTypesController < ResourceController
          private

          def model_class
            Spree::StoreCreditType
          end
        end
      end
    end
  end
end
