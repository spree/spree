module Spree
  module OrderRouting
    module Rules
      # Ranks the order's inferred preferred location at 0 and abstains for
      # everything else. Lets admins / staff / B2B contexts pin "fulfill from
      # this location" without preventing fallback when the preferred location
      # doesn't actually stock the items — subsequent rules tie-break.
      class PreferredLocation < Spree::OrderRoutingRule
        def rank(order, locations)
          preferred_id = order.inferred_preferred_stock_location_id

          locations.map do |loc|
            LocationRanking.new(
              location: loc,
              rank: (preferred_id.present? && loc.id.to_s == preferred_id.to_s) ? 0 : nil
            )
          end
        end
      end
    end
  end
end
