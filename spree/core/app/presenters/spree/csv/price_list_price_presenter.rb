module Spree
  module CSV
    # One rung of a price list as a CSV line. The headers are exactly the
    # import schema's fields, so an exported file maps onto the import without
    # anyone renaming a column, and every column in it means something on the
    # way back (docs/plans/6.0-volume-pricing.md).
    class PriceListPricePresenter
      HEADERS = Spree::ImportSchemas::PriceListPrices.new.headers.freeze

      def initialize(price)
        @price = price
      end

      attr_reader :price

      # @return [Array<String, Integer, nil>]
      def call
        [
          price.variant.sku,
          price.currency,
          price.min_quantity,
          amount_string(price.amount),
          amount_string(price.compare_at_amount)
        ]
      end

      private

      # The currency's own precision, a dot for the decimal mark and nothing
      # else — "18.00", never "$18.00", "18.0" or "18,00". Fixed rather than
      # localized because the file is read back by the import under the
      # store's locale, not the exporting admin's, and a comma written here
      # would re-import as a hundred times the price.
      def amount_string(amount)
        return nil if amount.nil?

        format("%.#{Spree::Money::Rounding.precision(price.currency)}f", amount)
      end
    end
  end
end
