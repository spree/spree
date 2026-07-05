module Spree
  module OrderRouting
    module Rules
      # Ranks the StockLocation marked `default: true` at 0 and others at 1.
      # Provides a deterministic baseline so the reducer always has a winner
      # once higher-priority rules abstain or tie.
      class DefaultLocation < Spree::OrderRoutingRule
        def rank(_order, locations)
          locations.map do |loc|
            LocationRanking.new(location: loc, rank: loc.default? ? 0 : 1)
          end
        end
      end
    end
  end
end
