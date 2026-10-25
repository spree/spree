module Spree
  module Adjusters
    # Largest-remainder apportionment of an integer total, in the currency's
    # minor units, across weights.
    # Shared by promotion order-level distribution and manual admin discounts
    # so both split identically (sum of shares always equals the total).
    module LargestRemainder
      module_function

      # @param total_cents [Integer]
      # @param weights [Array<Numeric>] proportional bases (sum must be > 0)
      # @return [Array<Integer>] per-weight shares in cents, summing to total_cents
      def largest_remainder_shares(total_cents, weights)
        weights_sum = weights.sum
        raw = weights.map { |weight| Rational(total_cents) * Rational(weight) / Rational(weights_sum) }
        shares = raw.map(&:floor)
        remainder = total_cents - shares.sum
        raw.each_with_index.sort_by { |value, index| [shares[index] - value, index] }.first(remainder).each do |_, index|
          shares[index] += 1
        end
        shares
      end

      # Splits an amount across weights in the currency's minor units, so the
      # shares are amounts that sum exactly to the one given.
      #
      # @param amount [BigDecimal]
      # @param weights [Array<Numeric>] proportional bases (sum must be > 0)
      # @param currency [String]
      # @return [Array<BigDecimal>]
      def apportion(amount, weights, currency)
        units = Spree::Money::Rounding.to_minor_units(amount, currency)
        largest_remainder_shares(units, weights).map { |share| Spree::Money::Rounding.from_minor_units(share, currency) }
      end
    end
  end
end
