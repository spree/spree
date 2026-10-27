module Spree
  module OrderRouting
    module Strategy
      # Default order routing strategy: walks Spree::OrderRoutingRule rows in
      # priority order, runs the Reducer to fully rank eligible locations,
      # packs each location, and lets Spree::Stock::Prioritizer distribute
      # inventory units across packages so units that the top-ranked
      # location can't cover spill over to subsequent locations.
      #
      # See docs/plans/6.0-order-routing.md.
      class Rules < Base
        def for_allocation
          locations = coordinator.candidate_stock_locations
          return [] if locations.empty?

          ordered = Spree::OrderRouting::Strategy::Reducer
            .new(applicable_rules.to_a, order: order)
            .rank_all(locations)
          return [] if ordered.empty?

          # Packed in rank order through the Coordinator, so an order allocates
          # under the same delivery profile and channel coverage as its cart,
          # and the Prioritizer's first-package-wins-on-hand logic honors the
          # routing decision between origins that can reach the destination.
          coordinator.estimate_packages(coordinator.allocated_packages(ordered))
        end

        # Stock decrement / restock today happens via Spree::Fulfillment's state
        # machine (after_ship / after_cancel). The strategy methods below are
        # part of the contract for the future reservation + typed-movement
        # phase — see 6.0-stock-reservations.md and 6.0-typed-stock-movements.md.
        # In 5.5 they are no-ops; the existing model callbacks already do the
        # right thing.
        def for_sale(fulfillment:); end
        def for_release; end
        def for_cancellation; end

        private

        def applicable_rules
          order.channel.order_routing_rules.active.ordered
        end

        def coordinator
          @coordinator ||= Spree::Stock::Coordinator.new(order)
        end
      end
    end
  end
end
