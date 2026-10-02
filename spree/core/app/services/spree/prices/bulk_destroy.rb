module Spree
  module Prices
    # Soft-deletes a set of prices together, or none of them. The batch is
    # judged on the ladders it leaves rather than one row at a time, so a
    # ladder's bottom rung deleted along with the breaks above it is not
    # refused partway through (docs/plans/6.0-volume-pricing.md).
    class BulkDestroy
      prepend Spree::ServiceModule::Base

      # @param prices [ActiveRecord::Relation, Array<Spree::Price>]
      # @return [Spree::ServiceModule::Result] success carries
      #   `{ price_count: N }`; fails with `rising_ladders:`, the same shape
      #   {Spree::Prices::BulkUpsert} refuses a save with
      def call(prices:)
        prices = prices.to_a

        rising = Spree::Price.rising_ladders_without(prices)
        return failure(nil, rising_ladders: rising) if rising.any?

        Spree::Price.transaction do
          prices.each do |price|
            price.skip_ladder_check = true
            price.destroy!
          end
        end

        success(price_count: prices.size)
      end
    end
  end
end
