module Spree
  module StockLocations
    module StockLevels
      class CreateJob < Spree::BaseJob
        queue_as Spree.queues.stock_location_stock_levels

        def perform(stock_location)
          Spree::StockLocations::StockLevels::Create.call(stock_location: stock_location)
        end
      end
    end
  end
end
