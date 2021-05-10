module Spree
  module Filters
    class PriceRange
      def self.from_param(param, currency:)
        prices = param.split('-')

        new(
          min_price: Price.new(amount: prices.first, currency: currency),
          max_price: Price.new(amount: prices.last, currency: currency)
        )
      end

      def initialize(min_price:, max_price:)
        @min_price = min_price
        @max_price = max_price
      end

      attr_reader :min_price, :max_price

      def to_param
        "#{min_price.to_i}-#{max_price.to_i}"
      end

      def to_s
        "#{min_price} - #{max_price}"
      end
    end
  end
end
