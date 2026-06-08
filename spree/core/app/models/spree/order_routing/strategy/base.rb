module Spree
  module OrderRouting
    module Strategy
      # Contract for order routing strategies. Subclasses implement all four
      # methods — there are no defaults. New routing *signals* (proximity,
      # day-of-week, etc.) ship as STI subclasses of Spree::OrderRoutingRule;
      # a custom strategy is appropriate only when the algorithm itself is a
      # different shape (OMS delegation, ML model, optimization solver).
      #
      # Selected per Order via Spree::Order#order_routing_strategy.
      # See docs/plans/6.0-order-routing.md.
      class Base
        attr_reader :order

        # Human label for admin strategy pickers. Override in a subclass or add
        # an i18n key under +spree.order_routing.strategies+.
        #
        # @return [String]
        def self.display_name
          Spree.t(name.demodulize.underscore, scope: 'order_routing.strategies', default: name.demodulize.titleize)
        end

        def initialize(order:)
          @order = order
        end

        # @return [Array<Spree::Stock::Package>]
        def for_allocation
          raise NotImplementedError, "#{self.class} must implement #for_allocation"
        end

        # @param fulfillment [Spree::Shipment]
        def for_sale(fulfillment:)
          raise NotImplementedError, "#{self.class} must implement #for_sale"
        end

        def for_release
          raise NotImplementedError, "#{self.class} must implement #for_release"
        end

        def for_cancellation
          raise NotImplementedError, "#{self.class} must implement #for_cancellation"
        end
      end
    end
  end
end
