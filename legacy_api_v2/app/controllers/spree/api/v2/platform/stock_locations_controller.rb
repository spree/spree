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

          def resource_serializer
            Spree.api.platform_stock_location_serializer
          end
        end
      end
    end
  end
end
