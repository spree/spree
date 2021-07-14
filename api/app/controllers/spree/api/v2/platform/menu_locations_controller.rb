module Spree
  module Api
    module V2
      module Platform
        class MenuLocationsController < ResourceController
          private

          def model_class
            Spree::MenuLocation
          end
        end
      end
    end
  end
end
