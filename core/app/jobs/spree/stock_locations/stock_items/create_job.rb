module Spree
  module StockLocations
    module StockItems
      class CreateJob < Spree::BaseJob
        queue_as :spree_stock_location_stock_items

        def perform(stock_location)
          Spree::StockLocations::StockItems::Create.call(stock_location: stock_location)
        end
      end
    end
  end
end
