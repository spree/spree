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

      # A plain decimal ("18.00", never "$18.00" or "18,00"): the import reads
      # the file back and accepts nothing else.
      def amount_string(amount)
        Spree::Money::Rounding.format(amount, price.currency, unit_price: true)
      end
    end
  end
end
