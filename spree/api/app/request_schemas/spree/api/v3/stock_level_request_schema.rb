module Spree
  module Api
    module V3
      # A variant's stock at one location.
      class StockLevelRequestSchema < Spree::Api::V3::RequestSchema
        publishes 'StockLevelParams'

        # Rows are matched by location: an `id` would be ignored.
        attribute :stock_location_id, :id, required: true, description: 'The location holding the stock (`sloc_...`).'
        attribute :count_on_hand, :integer,
          required: true,
          description: 'Units physically at the location, not units available to sell: stock promised to placed orders counts until it ships. Sent as the count the shelf should end at; the API records the difference as an adjustment in the stock history.'
        attribute :backorderable, :boolean,
          description: 'Whether this location sells the variant beyond what it holds.'
      end
    end
  end
end
