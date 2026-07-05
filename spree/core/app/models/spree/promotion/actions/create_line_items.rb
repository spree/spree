module Spree
  class Promotion
    module Actions
      class CreateLineItems < PromotionAction
        has_many :promotion_action_line_items, foreign_key: :promotion_action_id, dependent: :destroy

        attribute :promotion_action_line_items_attributes

        after_save :handle_promotion_action_line_items

        def self.additional_permitted_attributes
          [line_items: [:variant_id, :quantity]]
        end

        # API v3 flat alias for `promotion_action_line_items_attributes`.
        # Accepts an array of `{ variant_id:, quantity: }` rows; the list
        # is the *desired* set, so anything missing on save is removed.
        def line_items=(rows)
          self.promotion_action_line_items_attributes = rows
        end

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

        # Handles the creation, updating, and pruning of promotion action
        # line items. The submitted list is the *desired* set — variants
        # not present are deleted, ones that are get upserted. Accepts
        # both the legacy Rails admin hash shape (`{ "0" => attrs }`) and
        # a flat array from the API. Variant IDs may be raw or prefixed.
        def handle_promotion_action_line_items
          return unless promotion_action_line_items_attributes

          rows = promotion_action_line_items_attributes.is_a?(Hash) ? promotion_action_line_items_attributes.values : promotion_action_line_items_attributes
          rows = rows.map { |row| row.respond_to?(:to_h) ? row.to_h.with_indifferent_access : row.with_indifferent_access }

          rows = rows.map do |row|
            variant_id = row['variant_id']
            variant_id = Spree::Variant.find_by_param(variant_id)&.id if Spree::PrefixedId.prefixed_id?(variant_id)
            row.merge('variant_id' => variant_id)
          end

          desired_variant_ids = rows.map { |row| row['variant_id'] }.compact
          promotion_action_line_items.where.not(variant_id: desired_variant_ids).delete_all

          return if rows.empty?

          opts = {}
          opts[:unique_by] = [:promotion_action_id, :variant_id] unless mysql_adapter?

          promotion_action_line_items.upsert_all(
            rows.map do |params|
              {
                variant_id: params['variant_id'],
                quantity: params['quantity'],
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
