module Spree
  module StockReservations
    class InsufficientStockError < StandardError
      attr_reader :line_item

      def initialize(line_item, message)
        @line_item = line_item
        super(message)
      end
    end
  end
end
