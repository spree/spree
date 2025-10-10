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
            Spree::Api::Dependencies.platform_digital_serializer.constantize
          end
        end
      end
    end
  end
end
