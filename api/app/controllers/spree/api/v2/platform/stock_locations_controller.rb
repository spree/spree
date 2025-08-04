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
            Spree::Api::Dependencies.platform_stock_location_serializer.constantize
          end
        end
      end
    end
  end
end
