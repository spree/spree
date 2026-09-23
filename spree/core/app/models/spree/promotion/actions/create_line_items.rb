module Spree
  class Promotion
    module Actions
      class CreateLineItems < Spree::PromotionAction
        has_many :promotion_action_line_items, foreign_key: :promotion_action_id, dependent: :destroy

        attribute :promotion_action_line_items_attributes

        after_save :handle_promotion_action_line_items

        self.additional_permitted_attributes = [line_items: [:variant_id, :quantity]]

        # API v3 flat alias for `promotion_action_line_items_attributes`.
        # Accepts an array of `{ variant_id:, quantity: }` rows; the list
        # is the *desired* set, so anything missing on save is removed.
        def line_items=(rows)
          self.promotion_action_line_items_attributes = rows
        end

        delegate :eligible?, to: :promotion

        # @return [Symbol]
        def discount_scope
          :line_item
        end

        # The gift is rarely the product the rules name ("buy a coffee maker,
        # get a free tote"), so the rules decide whether the promotion applies
        # and this action decides which lines it pays for.
        #
        # @param order [Spree::Order, Spree::Cart]
        # @param line_item [Spree::LineItem]
        # @return [Boolean]
        def applies_to_line_item?(order, line_item)
          gifted_item?(line_item) && qualifies_beyond_the_gift?(order)
        end

        # Covers the gifted units of the line at their own price, leaving any
        # further units of the same variant the shopper bought themselves to be
        # paid for.
        #
        # @param line_item [Spree::LineItem]
        # @return [BigDecimal] never positive
        def compute_amount(line_item)
          line_item.price * gifted_quantity_of(line_item) * -1
        end

        # Tops the order up to the promised quantity and discounts it.
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
        # A shopper who already has the gift variant is given theirs free rather
        # than a duplicate, so the promotion still applies when it has nothing
        # to add.
        def perform(options = {})
          order = options[:order]
          return unless eligible? order
          return unless qualifies_beyond_the_gift?(order)

          added = add_missing_line_items(order)

          apply_via_adjuster(options) || added
        end

        # Called by promotion handler when a promotion is removed
        # This will find any line item matching the ones defined in the PromotionAction
        # and remove the same quantity as was added by the PromotionAction.
        def revert(options = {})
          order = options[:order]
          return if eligible?(order)
          return unless order.promotions.include?(promotion)

          action_taken = false
          promotion_action_line_items.each do |item|
            line_item = order.find_line_item_by_variant(item.variant)
            next unless line_item.present?

            remove_service = order.is_a?(Spree::Cart) ? Spree.cart_remove_item_service : Spree.order_remove_item_service
            remove_service.call(**{ (order.is_a?(Spree::Cart) ? :cart : :order) => order },
                                                variant: item.variant,
                                                quantity: (item.quantity || 1))
            action_taken = true
          end

          action_taken
        end

        # Checks that there's enough stock to add the line item to the order
        #
        # @param item [Spree::PromotionActionLineItem]
        # @param quantity [Integer] units wanted, defaulting to the whole gift
        # @return [Boolean]
        def item_available?(item, quantity = item.quantity)
          quantifier = Spree::Stock::Quantifier.new(item.variant)
          quantifier.can_supply? quantity
        end

        private

        # Whether this line holds a variant the promotion gives away.
        def gifted_item?(line_item)
          gifted_quantity_of(line_item).positive?
        end

        # A gift cannot be the thing that qualifies the order for the promotion
        # giving it away: a rule naming the gift's own product would otherwise
        # hand the item over to anyone who put it in their cart. The order has
        # to hold a line the rules count with units this action is not already
        # covering. A promotion with no rules qualifies on anything, so there is
        # nothing for the gift to stand in for.
        def qualifies_beyond_the_gift?(order)
          return true if promotion.promotion_rules.empty?

          order.line_items.any? do |line_item|
            promotion.line_item_actionable?(order, line_item) &&
              gifted_quantity_of(line_item) < line_item.quantity
          end
        end

        # How many units of this line the promotion pays for — never more than
        # the line holds, so a shopper buying three of a variant gifted once
        # still pays for two. `quantity` is nullable and written by `upsert_all`,
        # which skips validation, so a missing or negative one gifts nothing
        # rather than raising or turning the discount into a surcharge.
        #
        # @param line_item [Spree::LineItem]
        # @return [Integer]
        def gifted_quantity_of(line_item)
          gifted = promotion_action_line_items.detect { |item| item.variant_id == line_item.variant_id }
          return 0 if gifted.nil?

          [[line_item.quantity, gifted.quantity.to_i].min, 0].max
        end

        def add_missing_line_items(order)
          added_results = promotion_action_line_items.map do |item|
            missing = item.quantity.to_i - order.quantity_of(item.variant)
            next false unless missing.positive? && item_available?(item, missing)

            add_service = order.is_a?(Spree::Cart) ? Spree.cart_add_item_workflow : Spree.order_add_item_service
            result = add_service.call(**{ (order.is_a?(Spree::Cart) ? :cart : :order) => order },
                                      variant: item.variant,
                                      quantity: missing)
            result.success?
          end

          order.line_items.reload if added_results.any?

          added_results.any?
        end

        def promotion_variants_scope
          promotion.store.variants
        end

        # Handles the creation, updating, and pruning of promotion action
        # line items. The submitted list is the *desired* set — variants
        # not present are deleted, ones that are get upserted. Accepts
        # both the legacy Rails admin hash shape (`{ "0" => attrs }`) and
        # a flat array from the API. Variant IDs may be raw or prefixed.
        def handle_promotion_action_line_items
          return unless promotion_action_line_items_attributes

          rows = promotion_action_line_items_attributes.is_a?(Hash) ? promotion_action_line_items_attributes.values : promotion_action_line_items_attributes
          rows = rows.map { |row| row.respond_to?(:to_h) ? row.to_h.with_indifferent_access : row.with_indifferent_access }

          # Resolved through the promotion's own store, so a variant from
          # another store's catalog resolves to nothing and is dropped rather
          # than gifted by a promotion that cannot sell it. An unresolvable id
          # is dropped for the same reason a nil one always was — the upsert
          # would otherwise write a row with no variant.
          rows = rows.filter_map do |row|
            variant_id = row['variant_id']
            variant_id = promotion_variants_scope.find_by_param(variant_id)&.id if Spree::PrefixedId.prefixed_id?(variant_id)
            next if variant_id.blank?

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
