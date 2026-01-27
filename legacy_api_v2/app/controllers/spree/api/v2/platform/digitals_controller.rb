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

          def resource_serializer
            Spree.api.platform_digital_serializer
          end
        end
      end
    end
  end
end
