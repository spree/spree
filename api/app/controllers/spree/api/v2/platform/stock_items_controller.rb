module Spree
  module Api
    module V2
      module Platform
        class StockItemsController < ResourceController
          private

          def model_class
            Spree::StockItem
          end

          def scope_includes
            [:variant, :stock_location]
          end

          def resource_serializer
            Spree::Api::Dependencies.platform_stock_item_serializer.constantize
          end
        end
      end
    end
  end
end
