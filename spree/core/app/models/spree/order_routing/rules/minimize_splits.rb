module Spree
  module OrderRouting
    module Rules
      # Prefers locations that can fulfill more demand on their own.
      # Higher coverage → lower (better) rank, so the location that single-handedly
      # covers the most variants wins. Coverage is counted per distinct variant
      # so a variant repeated across multiple line items isn't double-counted.
      class MinimizeSplits < Spree::OrderRoutingRule
        def rank(order, locations)
          demand = required_quantity_by_variant(order)
          counts = stock_level_counts(demand.keys, locations)

          locations.map do |loc|
            coverage = demand.count do |variant_id, qty|
              (counts[[loc.id, variant_id]] || 0) >= qty
            end

            LocationRanking.new(location: loc, rank: -coverage)
          end
        end

        private

        def required_quantity_by_variant(order)
          order.line_items.each_with_object(Hash.new(0)) do |li, h|
            next if li.variant_id.nil?

            h[li.variant_id] += li.quantity
          end
        end

        # One query for the entire location × variant matrix instead of
        # N variants × M locations stock_level lookups. The reducer asks again
        # for every place in its ranking, each time about a subset of the
        # locations it asked about first, so the matrix is read once per
        # allocation rather than once per location.
        def stock_level_counts(variant_ids, locations)
          return {} if variant_ids.empty? || locations.empty?

          location_ids = locations.map(&:id)
          cached = @stock_level_counts
          if cached && cached[:variant_ids] == variant_ids && (location_ids - cached[:location_ids]).empty?
            return cached[:counts]
          end

          counts = Spree::StockLevel
            .where(stock_location_id: location_ids, variant_id: variant_ids)
            .pluck(:stock_location_id, :variant_id, :count_on_hand, :allocated_count)
            .each_with_object({}) { |(loc_id, var_id, on_hand, allocated), h| h[[loc_id, var_id]] = on_hand - allocated }

          @stock_level_counts = { variant_ids: variant_ids, location_ids: location_ids, counts: counts }
          counts
        end
      end
    end
  end
end
