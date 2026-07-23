module Spree
  module Adjusters
    # Base class for the adjusters run by the OrderUpdater recalculation
    # pipeline. Each adjuster declares its +type+ — :discount, :fee or :tax —
    # which fixes the pass it runs in (discounts → fees → tax; tax must run
    # last because it computes from the discounted basis). Registration order
    # in Spree.adjusters only matters within a type, so appending is always
    # safe.
    #
    # Adjusters work on the adjustables' preloaded associations in memory —
    # never re-query per adjustable — and write typed adjustment lines
    # (DiscountLine / Fee / TaxLine). Totals are rolled up afterwards by the
    # OrderUpdater; there is no totals bookkeeping in adjusters.
    class Base
      class_attribute :type, default: :fee

      # Pipeline entry point. The default runs the adjuster once per
      # adjustable; override for order-scoped work (Tax delegates to
      # TaxRate.adjust once; Promotion adds an order-wide pre-pass).
      def self.adjust_all(order, adjustables)
        adjustables.each { |adjustable| new(order, adjustable).update }
      end

      def initialize(order, adjustable)
        @order = order
        @adjustable = adjustable
      end

      def update
        raise NotImplementedError, "Please implement 'update' in your adjuster: #{self.class.name}"
      end

      private

      attr_reader :order, :adjustable
    end
  end
end
