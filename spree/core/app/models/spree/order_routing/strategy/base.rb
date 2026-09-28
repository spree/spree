module Spree
  module OrderRouting
    module Strategy
      # Contract for order routing strategies. Subclasses implement all three
      # methods — there are no defaults. New routing *signals* (proximity,
      # day-of-week, etc.) ship as STI subclasses of Spree::OrderRoutingRule;
      # a custom strategy is appropriate only when the algorithm itself is a
      # different shape (OMS delegation, ML model, optimization solver).
      #
      # Selected per cart or order via +order_routing_strategy+ (the channel's
      # choice, falling back to the store's), so storefront checkout and
      # staff-built orders route the same way.
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

        # @param order [Spree::Cart, Spree::Order] the purchase being routed
        def initialize(order:)
          @order = order
        end

        # Decides which locations fulfill which items. Called whenever a
        # cart's or order's fulfillments are (re)built.
        #
        # @return [Array<Spree::Stock::Package>]
        def for_allocation
          raise NotImplementedError, "#{self.class} must implement #for_allocation"
        end

        # Called once a fulfillment has been dispatched, after its stock
        # movements are committed — the point to settle whatever the
        # allocation reserved in an outside system.
        #
        # @param fulfillment [Spree::Fulfillment] the fulfillment that shipped
        def for_sale(fulfillment:)
          raise NotImplementedError, "#{self.class} must implement #for_sale"
        end

        # Called once an order has been canceled, after its fulfillments were
        # canceled and their stock released — the point to release whatever
        # the allocation reserved in an outside system. Orders can only be
        # canceled before anything ships.
        def for_release
          raise NotImplementedError, "#{self.class} must implement #for_release"
        end
      end
    end
  end
end
