module Spree
  module Adjustments
    # Splits an amount across line items proportionally to their amounts,
    # largest-remainder in cents: shares always sum exactly to the given
    # amount, ties broken by line item id. Whole-order promotion actions use
    # it at runtime and the Phase 3 backfill (spree:migrate_adjustments)
    # reuses it for frozen order-level adjustments — one splitting function,
    # one penny-placement behavior for runtime and migrated rows alike.
    class DistributeAmount
      # @param amount [BigDecimal, Numeric]
      # @param line_items [Enumerable<Spree::LineItem>]
      def initialize(amount:, line_items:)
        @amount = amount
        @line_items = line_items.sort_by(&:id)
      end

      # @return [Hash{Integer => BigDecimal}] line item id => share
      def call
        item_total = line_items.sum(&:amount)
        return {} if line_items.empty? || item_total <= 0

        total_cents = (amount * 100).round
        shares = line_items.index_with do |line_item|
          total_cents * line_item.amount / item_total
        end

        # truncate (toward zero) under-allocates every negative share,
        # e.g. -1000 in thirds → -333 each, deficit -1, one line gets -334.
        # Never claws a cent back.
        floored = shares.transform_values { |cents| cents.truncate }
        deficit = total_cents - floored.values.sum

        # deficit is a (negative) count of leftover cents; hand them to the
        # lines with the largest fractional remainders
        by_remainder = shares.keys.sort_by { |li| [-(shares[li] - floored[li]).abs, li.id] }
        by_remainder.first(deficit.abs).each { |li| floored[li] += deficit.negative? ? -1 : 1 }

        floored.to_h { |line_item, cents| [line_item.id, BigDecimal(cents) / 100] }
      end

      private

      attr_reader :amount, :line_items
    end
  end
end
