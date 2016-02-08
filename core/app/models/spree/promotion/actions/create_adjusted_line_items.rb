module Spree
  class Promotion
    module Actions
      class CreateAdjustedLineItems < CreateLineItems
        include Spree::CalculatedAdjustments
        include Spree::AdjustmentSource

        before_validation -> { self.calculator ||= Calculator::PercentOnLineItem.new }

        # Adds a line item with its discount to the Order if the promotion is eligible
        #
        #
        # e.g.
        #   - A promo adds a line item to cart if order total greater then $30
        #   - Customer add 1 item of $10 to cart and specifies a 50% discount on it.
        #   - This action shouldn't perform because the order is not eligible
        #   - Customer increases item quantity to 5 (order total goes to $50)
        #   - Now the order is eligible for the promo and the action should perform
        #   - Now cart contains 5 $10 items and 1 promotional item for $5. So total is $55.
        #
        # Another complication is when the same line item created by the promo
        # is also added to cart on a separate action.
        #
        # e.g.
        #   - Promo adds 1 item A to cart if order total greater then $30
        #   - Customer add 2 items B to cart, current order total is $40
        #   - This action performs adding item A to cart since order is eligible
        #   - Customer changes his mind and updates item B quantity to 1
        #   - At this point order is no longer eligible and one might expect
        #     that item A should be removed
        #
        # It doesn't remove items from the order here because there's no way
        # it can know whether that item was added via this promo action or if
        # it was manually populated somewhere else, but the promotion discount
        # on the order is removed. If the user needs to remove the promotional line items
        # It can be removed manually.
        def perform(options = {})
          order = options[:order]

          promotion_action_line_items.map do |item|
            add_line_item(order, item, order.quantity_of(item.variant))
          end.any? | create_unique_adjustments(order, order.line_items)
        end

        def compute_amount(line_item)
          return 0 unless promotion.line_item_actionable?(line_item.order, line_item)
          return 0 unless promotion_action_line_items_include?(line_item)
          [line_item.amount, compute(line_item)].min * -1 * amount_adjustment_factor(line_item)
        end

        private

        def amount_adjustment_factor(line_item)
          [promotion_action_line_item_for(line_item).quantity, line_item.quantity].min.to_f / line_item.quantity
        end

        def promotion_action_line_items_include?(line_item)
          line_item && promotion_action_line_item_for(line_item)
        end

        def promotion_action_line_item_for(line_item)
          promotion_action_line_items.detect { |item| item.variant_id == line_item.variant_id }
        end

        def add_line_item(order, item, current_quantity)
          if current_quantity < item.quantity && item_available?(item)
            line_item = order.contents.add(item.variant, item.quantity - current_quantity)
            line_item.try(:valid?)
          end
        end
      end
    end
  end
end
