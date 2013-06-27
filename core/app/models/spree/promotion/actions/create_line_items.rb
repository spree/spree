module Spree
  class Promotion
    module Actions
      class CreateLineItems < PromotionAction
        has_many :promotion_action_line_items, foreign_key: :promotion_action_id
        accepts_nested_attributes_for :promotion_action_line_items

        delegate :eligible?, :to => :promotion

        # Adds a line item to the Order if the promotion is eligible
        #
        # This doesn't play right with Add to Cart events because at the moment
        # the item was added to cart the promo may not be eligible. However it
        # might become eligible as the order gets updated.
        #
        # e.g.
        #   - A promo adds a line item to cart if order total greater then $30
        #   - Customer add 1 item of $10 to cart
        #   - This action shouldn't perform because the order is not eligible
        #   - Customer increases item quantity to 5 (order total goes to $50)
        #   - Now the order is eligible for the promo and the action should perform
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
        # it was manually populated somewhere else. In that case the item
        # needs to be manually removed from the order by the customer
        def perform(options = {})
          order = options[:order]
          return unless self.eligible? order

          promotion_action_line_items.each do |item|
            current_quantity = order.quantity_of(item.variant)
            if current_quantity < item.quantity
              order.contents.add(item.variant, item.quantity - current_quantity)
            end
          end
        end
      end
    end
  end
end
