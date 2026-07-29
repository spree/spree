module Spree
  module Adjusters
    # Largest-remainder apportionment of an integer cent total across weights.
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
    end
  end
end
