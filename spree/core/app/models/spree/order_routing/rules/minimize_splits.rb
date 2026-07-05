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
          counts = stock_item_counts(demand.keys, locations)

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
        # N variants × M locations stock_item lookups.
        def stock_item_counts(variant_ids, locations)
          return {} if variant_ids.empty? || locations.empty?

          Spree::StockItem
            .where(stock_location_id: locations.map(&:id), variant_id: variant_ids)
            .pluck(:stock_location_id, :variant_id, :count_on_hand)
            .each_with_object({}) { |(loc_id, var_id, count), h| h[[loc_id, var_id]] = count }
        end
      end
    end
  end
end
