module Spree
  class Promotion
    module Actions
      class CreateLineItems < PromotionAction
        has_many :promotion_action_line_items, foreign_key: :promotion_action_id, dependent: :destroy

        attribute :promotion_action_line_items_attributes

        after_save :handle_promotion_action_line_items

        delegate :eligible?, to: :promotion

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
          return unless eligible? order

          action_taken = false
          promotion_action_line_items.each do |item|
            current_quantity = order.quantity_of(item.variant)
            next unless current_quantity < item.quantity && item_available?(item)

            line_item = Spree.cart_add_item_service.call(order: order,
                                                         variant: item.variant,
                                                         quantity: item.quantity - current_quantity).value
            action_taken = true if line_item.try(:valid?)
          end
          action_taken
        end

        # Called by promotion handler when a promotion is removed
        # This will find any line item matching the ones defined in the PromotionAction
        # and remove the same quantity as was added by the PromotionAction.
        # Should help to prevent some of cases listed above the #perform method
        def revert(options = {})
          order = options[:order]
          return if eligible?(order)

          action_taken = false
          promotion_action_line_items.each do |item|
            line_item = order.find_line_item_by_variant(item.variant)
            next unless line_item.present?

            Spree.cart_remove_item_service.call(order: order,
                                                variant: item.variant,
                                                quantity: (item.quantity || 1))
            action_taken = true
          end

          action_taken
        end

        # Checks that there's enough stock to add the line item to the order
        def item_available?(item)
          quantifier = Spree::Stock::Quantifier.new(item.variant)
          quantifier.can_supply? item.quantity
        end

        private

        # Handles the creation and updating of promotion action line items
        #
        # This is a hacky replacement for accepts_nested_attributes_for
        # that allows us to save the PromotionAction and PromotionActionLineItems
        # at the same time.
        def handle_promotion_action_line_items
          return unless promotion_action_line_items_attributes

          # remove the ones marked for destruction
          ids_for_destruction = promotion_action_line_items_attributes.map { |key, params| params["_destroy"] == "1" ? params["id"] : nil }.compact
          promotion_action_line_items.where(id: ids_for_destruction).delete_all if ids_for_destruction.present?

          # upsert the rest
          records_for_upsert = promotion_action_line_items_attributes.map { |key, params| params["_destroy"] != "1" ? params : nil }.compact

          opts = {}
          opts[:unique_by] = [:promotion_action_id, :variant_id] unless ActiveRecord::Base.connection.adapter_name == 'Mysql2'

          promotion_action_line_items.upsert_all(
            records_for_upsert.map do |params|
              {
                variant_id: params["variant_id"],
                quantity: params["quantity"],
                promotion_action_id: id
              }
            end,
            **opts
          )
        end
      end
    end
  end
end
