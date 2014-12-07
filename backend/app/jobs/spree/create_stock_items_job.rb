module Spree
  class CreateStockItemsJob < ActiveJob::Base
    queue_as :default

    def perform(stock_location_id)
      ::Mutex.new.synchronize do
        stock_location = StockLocation.find(stock_location_id)

        Variant.find_each do |variant|
          stock_location.propagate_variant variant
        end
      end
    end
  end
end
