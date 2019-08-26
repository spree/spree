module Spree
  class Promotion
    module Actions
      class CreateItemAdjustments < PromotionAction
        include Spree::CalculatedAdjustments
        include Spree::AdjustmentSource

        before_validation -> { self.calculator ||= Calculator::Promotion::FlatPercent.new }

        def perform(options = {})
          order     = options[:order]
          promotion = options[:promotion]

          create_unique_adjustments(order, order.line_items) do |line_item|
            promotion.line_item_actionable?(order, line_item)
          end
        end

        def compute_amount(line_item)
          order = line_item.order
          return 0 unless promotion.line_item_actionable?(order, line_item)

          matched_line_items = order.line_items.select do |line_item|
            promotion.line_item_actionable?(order, line_item)
          end

          ams = []
          matched_line_items.each do |i|
            unless i.equal?(matched_line_items.last)
              ams << i.amount
            end
          end

          total = matched_line_items.sum(&:amount)
          if matched_line_items.last.id == matched_line_items.first.id
            id = nil
          else
            id = matched_line_items.last.id
          end

          amounts = [line_item.amount, compute(line_item, total, id, ams)]
          amounts << order.amount - order.adjustments.sum(:amount).abs if order.adjustments.any?
          amounts.min * -1
        end
      end
    end
  end
end
