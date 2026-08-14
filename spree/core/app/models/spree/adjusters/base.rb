module Spree
  module Adjusters
    # Base class for adjusters registered in +Spree.adjusters+. An adjuster is
    # invoked once per order recalculation and owns a family of typed rows
    # (Discount or Fee) — it writes, refreshes and removes them so the rows
    # always reflect the order's current state. Tax is not an adjuster; it is
    # written by the sale's tax provider after all adjusters ran.
    class Base
      def self.adjust(order)
        new(order).update
      end

      def initialize(order)
        @order = order
      end

      def update
        raise NotImplementedError, "Please implement 'update' in your adjuster: #{self.class.name}"
      end

      private

      attr_reader :order
    end
  end
end
