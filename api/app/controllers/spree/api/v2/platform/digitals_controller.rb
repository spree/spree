module Spree
  module Api
    module V2
      module Platform
        class DigitalsController < ResourceController
          private

          def model_class
            Spree::Digital
          end

          def spree_permitted_attributes
            super + [:attachment]
          end
        end
      end
    end
  end
end
