module Spree
  module OrderRouting
    module Strategy
      # Default order routing strategy: walks Spree::OrderRoutingRule rows in
      # priority order, runs the Reducer to fully rank the candidate
      # locations, and hands that ranking to Spree::Stock::Coordinator, which
      # packs each location and lets the Prioritizer spill units the
      # top-ranked location can't cover over to the next ones.
      #
      # The Coordinator keeps owning which locations are candidates at all and
      # which items each one may pack (delivery profile coverage, the channel's
      # served locations), so routing only ever reorders origins that are
      # already allowed.
      #
      # See docs/plans/6.0-order-routing.md.
      class Rules < Base
        def for_allocation
          locations = coordinator.stock_locations
          return [] if locations.empty?

          ranked = Spree::OrderRouting::Strategy::Reducer
            .new(applicable_rules, order: order)
            .rank_all(locations)
          return [] if ranked.empty?

          coordinator.packages(ranked)
        end

        # The fulfillment and order workflows write the stock movements for
        # dispatch and cancellation themselves, so the rules strategy has
        # nothing to add at these points.
        def for_sale(fulfillment:); end
        def for_release; end

        private

        def applicable_rules
          channel = order.channel || order.store.default_channel
          return [] if channel.nil?

          channel.order_routing_rules.active.ordered.to_a
        end

        def coordinator
          @coordinator ||= Spree::Stock::Coordinator.new(order)
        end
      end
    end
  end
end
