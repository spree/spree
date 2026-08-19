module Spree
  module StockLocations
    module StockItems
      # @deprecated Renamed to Spree::StockLocations::StockLevels::CreateJob in 6.0.
      #   Subclasses it so jobs enqueued under the old class name before the deploy
      #   still deserialize and run; removed in 6.1.
      class CreateJob < StockLevels::CreateJob
        def perform(*args)
          Spree::Deprecation.warn('Spree::StockLocations::StockItems::CreateJob is deprecated and will be removed in Spree 6.1. Use Spree::StockLocations::StockLevels::CreateJob instead.')
          super
        end
      end
    end
  end
end
