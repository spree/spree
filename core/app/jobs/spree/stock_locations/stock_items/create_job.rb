module Spree
  module StockLocations
    module StockItems
      class CreateJob < ApplicationJob
        def perform(stock_location)
          Spree::StockLocations::StockItems::Create.call(stock_location: stock_location)
        end
      end
    end
  end
end
