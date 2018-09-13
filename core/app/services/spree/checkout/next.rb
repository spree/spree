module Spree
  module Checkout
    class Next
      def initialize(order)
        @order = order
      end

      def call
        order.next
      end

      private

      attr_reader :order
    end
  end
end
