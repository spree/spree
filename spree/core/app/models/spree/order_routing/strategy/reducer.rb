require 'set'

module Spree
  module OrderRouting
    module Strategy
      # Walks rules in priority order and applies a "first non-tie wins" reducer.
      #
      # For each rule:
      #   1. Drop rankings where rank is nil (rule abstains for that location).
      #   2. Find the location(s) with the lowest rank (best).
      #   3. Unique winner -> return it.
      #   4. Tie -> carry the tied set forward to the next rule.
      #
      # Out of rules with ties: prefer the StockLocation marked default,
      # then by id. Guarantees a winner whenever locations is non-empty.
      class Reducer
        def initialize(rules, order:)
          @rules = rules
          @order = order
        end

        # @param locations [Array<Spree::StockLocation>]
        # @return [Spree::StockLocation, nil]
        def pick(locations)
          return nil if locations.empty?

          remaining = locations
          remaining_ids = remaining.map(&:id).to_set

          @rules.each do |rule|
            rankings = rule.rank(@order, remaining).select do |r|
              r.rank && remaining_ids.include?(r.location.id)
            end
            next if rankings.empty?

            min_rank = rankings.map(&:rank).min
            top = rankings.select { |r| r.rank == min_rank }.map(&:location)

            return top.first if top.size == 1

            remaining = top
            remaining_ids = top.map(&:id).to_set
          end

          remaining.min_by { |l| [l.default? ? 0 : 1, l.id] }
        end

        # Returns every input location, ordered best-first by the same rule
        # chain that drives #pick. Each successive location is the best of
        # what remains — used by Strategy::Rules to fan out an allocation
        # across multiple locations when no single location covers the cart.
        #
        # @param locations [Array<Spree::StockLocation>]
        # @return [Array<Spree::StockLocation>]
        def rank_all(locations)
          remaining = locations.dup
          ordered = []
          until remaining.empty?
            chosen = pick(remaining) or break
            ordered << chosen
            remaining = remaining.reject { |l| l.id == chosen.id }
          end
          ordered
        end
      end
    end
  end
end
