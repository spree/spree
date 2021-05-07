module Spree
  module Filters
    class PriceRange
      def initialize(min_price:, max_price:)
        @min_price = min_price
        @max_price = max_price
      end

      def to_param
        "#{min_price.to_i}-#{max_price.to_i}"
      end

      def to_s
        "#{min_price} - #{max_price}"
      end

      private

      attr_reader :min_price, :max_price
    end
  end
end
