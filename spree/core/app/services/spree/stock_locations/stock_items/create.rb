module Spree
  module StockLocations
    module StockItems
      # @deprecated Renamed to Spree::StockLocations::StockLevels::Create in 6.0.
      #   This shim delegates to the renamed service so host code calling the old
      #   name keeps working; removed in 6.1.
      class Create
        prepend Spree::ServiceModule::Base

        # @param stock_location [Spree::StockLocation]
        # @param variants_scope [ActiveRecord::Relation]
        # @return [Spree::ServiceModule::Base::Result]
        def call(stock_location:, variants_scope: Spree::Variant)
          Spree::Deprecation.warn('Spree::StockLocations::StockItems::Create is deprecated and will be removed in Spree 6.1. Use Spree::StockLocations::StockLevels::Create instead.')
          Spree::StockLocations::StockLevels::Create.call(stock_location: stock_location, variants_scope: variants_scope)
        end
      end
    end
  end
end
