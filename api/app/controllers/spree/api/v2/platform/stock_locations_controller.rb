module Spree
  module Api
    module V2
      module Platform
        class StockLocationsController < ResourceController
          private

          def model_class
            Spree::StockLocation
          end

          def scope_includes
            [:country]
          end
        end
      end
    end
  end
end
