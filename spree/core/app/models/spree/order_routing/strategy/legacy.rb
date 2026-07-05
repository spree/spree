module Spree
  module OrderRouting
    module Strategy
      # Pre-5.5 routing behavior. Delegates to Spree::Stock::Coordinator,
      # which packs every active stock location and lets Prioritizer's
      # Adjuster distribute units across the resulting packages — no rules
      # consulted, no merchant-driven preferences, location order is
      # whatever the database returns.
      #
      # Provided as an opt-in escape hatch for merchants upgrading from 5.4
      # who are not ready to adopt rules-based routing. Configure via:
      #
      #   store.update!(preferred_order_routing_strategy: 'Spree::OrderRouting::Strategy::Legacy')
      #
      # Spree 6.0 drops this strategy along with the underlying Coordinator.
      # See docs/plans/6.0-order-routing.md.
      class Legacy < Base
        def for_allocation
          Spree::Stock::Coordinator.new(order).packages
        end

        # Stock decrement / restock today happens via Spree::Shipment's state
        # machine (after_ship / after_cancel). The strategy hooks below are
        # part of the contract for the future reservation + typed-movement
        # phase. In 5.5 they are no-ops; existing model callbacks already do
        # the right thing.
        def for_sale(fulfillment:); end
        def for_release; end
        def for_cancellation; end
      end
    end
  end
end
