module Spree
  module Api
    module V2
      module Platform
        class DigitalsController < ResourceController
          private

          def model_class
            Spree::Digital
          end

          def permitted_resource_params
            params.require(model_param_name).permit(spree_permitted_attributes << :attachment)
          end
        end
      end
    end
  end
end
