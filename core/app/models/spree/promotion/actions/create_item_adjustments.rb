module Spree
  class Promotion
    module Actions
      class CreateItemAdjustments < PromotionAction
        include Spree::CalculatedAdjustments
        include Spree::AdjustmentSource

        before_validation -> { self.calculator ||= Calculator::PercentOnLineItem.new }

        def perform(options = {})
          order     = options[:order]
          promotion = options[:promotion]

          create_unique_adjustments(order, order.line_items) do |line_item|
            promotion.line_item_actionable?(order, line_item)
          end
        end

        def compute_amount(line_item)
          return 0 unless promotion.line_item_actionable?(line_item.order, line_item)

          order = line_item.order

          # Get all actionable line items
          matched_line_items = order.line_items.select do |item|
            promotion.line_item_actionable?(order, item)
          end

          # Get an array of all actionable amounts
          ams = []
          matched_line_items.each do |i|
            unless i.equal?(matched_line_items.last)
              ams << i.amount
            end
          end

          # Get the actionable amounts total value
          actionable_items_total = matched_line_items.sum(&:amount)

          # Get the ID of the last actionable line item, unless it is the only actionable line item
          last_item_id = matched_line_items.last.id unless matched_line_items.last.id == matched_line_items.first.id

          # Set the line item preferences hash
          line_item[:preferences] = { actionable_amounts: ams, actionable_total: actionable_items_total, last_actionable_line_item_id: last_item_id }

          amounts = [line_item.amount, compute(line_item)]
          order   = line_item.order

          # Prevent negative order totals
          amounts << order.amount - order.adjustments.eligible.sum(:amount).abs if order.adjustments.eligible.any?

          amounts.min * -1
        end
      end
    end
  end
end
