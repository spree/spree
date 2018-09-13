module Spree
  module Checkout
    class Advance
      def initialize(order)
        @order = order
      end

      def call
        Spree::Checkout::Next.new(order).call until cannot_make_transition?
      end

      private

      attr_reader :order

      def cannot_make_transition?
        order.confirm? || order.complete? || order.errors.present?
      end
    end
  end
end
