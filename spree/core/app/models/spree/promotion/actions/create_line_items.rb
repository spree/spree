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

        # Covers the gifted units of the line at their own price, leaving the
        # units of the same variant the shopper chose themselves to be paid for.
        #
        # @param line_item [Spree::LineItem]
        # @return [BigDecimal] never positive
        def compute_amount(line_item)
          -Spree::Money::Rounding.to_currency(line_item.price * gifted_quantity_of(line_item), line_item.currency)
        end

        # Adds the promised quantity on top of anything the shopper chose and
        # discounts it.
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
        def perform(options = {})
          order = options[:order]
          return unless eligible? order
          return unless qualifies_beyond_the_gift?(order) || settle_gifts_left_qualifying(order)

          # A gift list edited while carts hold the old gift trims them to it.
          take_back_gifts(order) { |line_item, given| given - promised_quantity_of(line_item) }
          added = add_missing_line_items(order)

          apply_via_adjuster(options) || added
        end

        # Called by promotion handler when a promotion is removed
        def revert(options = {})
          order = options[:order]
          return if eligible?(order)
          return unless order.promotions.include?(promotion)

          remove_gifts(order)
        end

        # Takes back every unit this action recorded as given, leaving the ones
        # the shopper chose, including a gift its list no longer names.
        #
        # @param order [Spree::Order, Spree::Cart]
        # @return [Boolean] whether anything was removed
        def remove_gifts(order)
          take_back_gifts(order) { |_line_item, given| given }
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

        # Whether the promotion gives its gift on this order, judged with other
        # promotions' gifts still counting toward its own rules — a single
        # level, so two gift promotions measuring each other cannot loop.
        #
        # @param order [Spree::Order, Spree::Cart]
        # @return [Boolean]
        def gives_away?(order)
          promotion.eligible?(order, own_gift_only: true) && qualifies_beyond_the_gift?(order, own_gift_only: true)
        end

        # How many units of this line the promotion pays for — only units added
        # as a gift, never the ones the shopper chose, and never more than the
        # promotion promises. `quantity` is nullable and written by `upsert_all`,
        # which skips validation, so a missing or negative one gifts nothing
        # rather than raising or turning the discount into a surcharge.
        #
        # @param line_item [Spree::LineItem]
        # @return [Integer]
        def gifted_quantity_of(line_item)
          promised = promised_quantity_of(line_item)
          return 0 unless promised.positive?

          [[line_item.quantity, line_item.gifted_quantity_by(self), promised].min, 0].max
        end

        private

        # Whether this line holds a variant the promotion gives away.
        def gifted_item?(line_item)
          gifted_quantity_of(line_item).positive?
        end

        # A gift cannot be the thing that qualifies the order for a promotion,
        # or a rule naming the gift's own product would keep the offer alive on
        # its own gift. The order has to hold a line the rules count with units
        # the shopper chose. A promotion with no rules
        # qualifies on anything, so there is nothing for the gift to stand in for.
        def qualifies_beyond_the_gift?(order, options = {})
          return true if promotion.promotion_rules.empty?

          line_items_with_gifts(order).any? do |line_item|
            promotion.line_item_actionable?(order, line_item, options) &&
              line_item.gifted_quantity < line_item.quantity
          end
        end

        # Eligible on its own gift alone: a "buy one, get one" line lowered to
        # the gift, or the item that earned it removed. Gift units of a product
        # the rules count become the shopper's, so the offer applies to them
        # again; a gift of anything else is taken back.
        def settle_gifts_left_qualifying(order)
          holding = line_items_with_gifts(order).select { |line_item| line_item.gifted_quantity_by(self).positive? }
          counted, others = holding.partition { |line_item| promotion.line_item_actionable?(order, line_item) }

          counted.each do |line_item|
            line_item.gifts.destroy(line_item.gifts.detect { |gift| gift.promotion_action_id == id })
          end
          take_back_gifts(order) { |_line_item, given| given } if others.any?

          counted.any? && qualifies_beyond_the_gift?(order)
        end

        def promised_quantity_of(line_item)
          promotion_action_line_items.detect { |item| item.variant_id == line_item.variant_id }&.quantity.to_i
        end

        # Removes from each line holding this action's gift the units the block
        # returns, never more than were given.
        def take_back_gifts(order)
          holding = line_items_with_gifts(order).select { |line_item| line_item.gifted_quantity_by(self).positive? }
          holding.map do |line_item|
            given = line_item.gifted_quantity_by(self)
            units = [yield(line_item, given), given].min
            next false unless units.positive?

            call_item_service(order, Spree.cart_remove_item_service, Spree.order_remove_item_service, line_item.variant, units, line_item: line_item)
            true
          end.any?
        end

        # Loaded once for the cart rather than once per line, leaving lines
        # whose gifts are already in memory untouched.
        def line_items_with_gifts(order)
          line_items = order.line_items.to_a
          unloaded = line_items.reject { |line_item| line_item.association(:gifts).loaded? }
          ActiveRecord::Associations::Preloader.new(records: unloaded, associations: :gifts).call if unloaded.any?
          line_items
        end

        def add_missing_line_items(order)
          attempted = false
          added_results = promotion_action_line_items.map do |item|
            line_item = order.find_line_item_by_variant(item.variant)
            # A line carries one promotion discount, so a second promotion's
            # gift beside another's would leave one of them charged.
            next false if line_item && line_item.gifted_quantity > line_item.gifted_quantity_by(self)

            missing = item.quantity.to_i - (line_item ? gifted_quantity_of(line_item) : 0)
            next false unless missing.positive? && item_available?(item, missing)

            attempted = true
            call_item_service(order, Spree.cart_add_item_workflow, Spree.order_add_item_service, item.variant, missing).success?
          end

          # A refused add leaves its raised quantity and unsaved gift on the
          # line in memory, where the discount would read them.
          order.line_items.reload if attempted

          added_results.any?
        end

        def call_item_service(order, cart_service, order_service, variant, quantity, **target_line)
          if order.is_a?(Spree::Cart)
            cart_service.call(cart: order, variant: variant, quantity: quantity, gift: self, **target_line)
          else
            order_service.call(order: order, variant: variant, quantity: quantity, gift: self, **target_line)
          end
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
