module Spree
  class Promotion
    module Actions
      # A whole-order discount. There are no order-level discount rows: the
      # computed amount is distributed proportionally across the line items
      # (docs/plans/6.0-split-adjustments.md, Resolved Question 1), so taxes,
      # refunds, and marketplace order-splitting always see per-line money.
      class CreateAdjustment < PromotionAction
        include Spree::CalculatedAdjustments

        before_validation -> { self.calculator ||= Calculator::FlatPercentItemTotal.new }

        def self.additional_permitted_attributes
          [calculator: [:type, { preferences: {} }]]
        end

        def perform(options = {})
          order = options[:order]

          results = distributed_amounts(order).map do |line_item, amount|
            upsert_discount_line(order, line_item, amount)
          end

          results.include?(true)
        end

        # The line item's deterministic share of the whole-order discount —
        # recalculation reproduces exactly the split activation wrote.
        def compute_amount(line_item)
          distributed_amounts(line_item.order)[line_item] || 0
        end

        def order_total(order)
          order.item_total + order.ship_total - order.shipping_discount
        end

        private

        # Splits the whole-order discount across line items proportionally to
        # their amounts. Largest-remainder in cents: shares always sum exactly
        # to the computed discount, ties broken by line item id.
        #
        # @return [Hash{Spree::LineItem => BigDecimal}]
        def distributed_amounts(order)
          line_items = order.line_items.sort_by(&:id)
          item_total = line_items.sum(&:amount)
          return {} if line_items.empty? || item_total <= 0

          total_cents = (compute_order_discount(order) * 100).round
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

          floored.transform_values { |cents| BigDecimal(cents) / 100 }
        end

        def compute_order_discount(order)
          [order_total(order), compute(order)].min * -1
        end
      end
    end
  end
end
