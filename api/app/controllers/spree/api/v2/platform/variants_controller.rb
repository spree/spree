module Spree
  module Api
    module V2
      module Platform
        class VariantsController < ResourceController
          private

          def model_class
            Spree::Variant
          end
        end
      end
    end
  end
end
