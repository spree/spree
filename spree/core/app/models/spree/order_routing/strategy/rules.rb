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
          locations = eligible_locations
          return [] if locations.empty?

          ordered = Spree::OrderRouting::Strategy::Reducer
            .new(applicable_rules.to_a, order: order)
            .rank_all(locations)
          return [] if ordered.empty?

          packages = build_packages(ordered)
          packages = prioritize_packages(packages)
          estimate_rates(packages)
        end

        # Stock decrement / restock today happens via Spree::Shipment's state
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

        def eligible_locations
          Spree::StockLocation.active
            .joins(:stock_items)
            .where(spree_stock_items: { variant_id: requested_variant_ids })
            .distinct
            .to_a
        end

        def requested_variant_ids
          inventory_units.map(&:variant_id).uniq
        end

        def inventory_units
          @inventory_units ||= Spree::Stock::InventoryUnitBuilder.new(order).units
        end

        # Pack each ranked location independently. Packages are emitted in
        # rank order so the Prioritizer's first-package-wins-on-hand logic
        # honors the routing decision.
        def build_packages(locations)
          locations.flat_map do |location|
            Spree::Stock::Packer.new(location, inventory_units, Spree.stock_splitters).packages
          end
        end

        # Prioritizer's Adjuster distributes each inventory_unit across
        # packages: the first package with on-hand stock fulfills the unit,
        # and downstream packages have that unit removed. Packages whose
        # items all get stripped are pruned.
        def prioritize_packages(packages)
          Spree::Stock::Prioritizer.new(packages).prioritized_packages
        end

        def estimate_rates(packages)
          estimator = Spree::Stock::Estimator.new(order)
          packages.each { |pkg| pkg.shipping_rates = estimator.shipping_rates(pkg) }
          packages
        end
      end
    end
  end
end
