module Spree
  module Api
    module V3
      # A variant's stock at one location.
      class StockLevelRequestSchema < Spree::Api::V3::RequestSchema
        publishes 'StockLevelParams'

        id :id
        id :stock_location_id, required: true, description: 'The location holding the stock (`sloc_...`).'
        integer :count_on_hand, required: true,
                                description: 'Units physically at the location, not units available to sell: stock promised to placed orders counts until it ships. Sent as the count the shelf should end at; the API records the difference as an adjustment in the stock history.'
        boolean :backorderable, description: 'Whether this location sells the variant beyond what it holds.'
      end
    end
  end
end
