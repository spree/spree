module Spree
  module Checkout
    class Complete
      def initialize(order)
        @order = order
      end

      def call
        Spree::Checkout::Next.new(order).call until cannot_make_transition?
      end

      private

      attr_reader :order

      def cannot_make_transition?
        order.complete? || order.errors.present?
      end
    end
  end
end
