module Spree
  module Purchase
    # How much of a thing this buyer may order, and how much the order as a
    # whole must come to — shared by Spree::Cart and Spree::Order.
    #
    # Everything here is computed from the buyer's catalogs and never stored:
    # an agreement is a live fact about the relationship, so a cart reads
    # today's terms rather than the ones it was built under. A placed order
    # resolves the same way for display, but nothing re-validates it — the
    # sale already happened (docs/plans/6.0-b2b-quantity-rules.md).
    module QuantityRules
      extend ActiveSupport::Concern

      # True when this purchase is staff's to key in rather than a buyer's to
      # build. Two signals, because either alone leaves a gap: an incomplete
      # order is the admin draft surface whether or not a creator was
      # recorded (both draft workflows take `created_by` optionally), and a
      # cart cannot carry one at all.
      #
      # Staff are unrestricted by the quantity terms — an admin is entering
      # what the buyer actually negotiated, and refusing it would make an
      # agreed exception impossible to record.
      #
      # A placed order is nobody's draft, so it is excluded: post-placement
      # item changes go through the admin surface with a creator, and the
      # exemption should come from that rather than from the sale having
      # already happened.
      #
      # @return [Boolean]
      def staff_initiated?
        (is_a?(Spree::Order) && !completed?) ||
          (respond_to?(:created_by_id) && created_by_id.present?)
      end

      # Why this buyer may not order that many of a variant, naming what they
      # may order instead — nil when the quantity is fine, and nil for staff,
      # who are unrestricted. The one place the three enforcement points get
      # their answer, so they all refuse in the same words.
      #
      # @param variant [Spree::Variant]
      # @param quantity [Integer]
      # @param name [String, nil] what to call the item; defaults to the variant
      # @return [String, nil]
      def quantity_rule_violation(variant, quantity, name: nil)
        return nil if staff_initiated?

        quantity_rules_for(variant).violation_message(name || variant.name, quantity)
      end

      # The buyer's effective rules for one variant: their catalogs' terms
      # resolved per field over the variant's own base rules.
      #
      # @param variant [Spree::Variant]
      # @return [Spree::QuantityRule]
      def quantity_rules_for(variant)
        quantity_rules_resolver.call(variant)
      end

      # The order minimum in force for this purchase's currency, or nil when
      # the buyer's agreements state none.
      #
      # @return [Spree::CatalogOrderMinimum, nil]
      def order_minimum
        return @order_minimum if defined?(@order_minimum)

        @order_minimum = quantity_rules_resolver.order_minimum(currency)
      end

      # @return [BigDecimal, nil] the amount that must be reached, or nil
      def order_minimum_amount
        order_minimum&.amount
      end

      # What still has to be added to reach the minimum, or nil when there is
      # no minimum. Zero once it is met, so callers can render "$180 to go"
      # from one number.
      #
      # Measured against the item total rather than the order total: delivery
      # and tax are not what the buyer bought, and a threshold met by adding
      # a faster shipping option is not a minimum order.
      #
      # @return [BigDecimal, nil]
      def order_minimum_shortfall
        amount = order_minimum_amount
        return nil if amount.nil?

        [amount - item_total, 0].max
      end

      # @return [Boolean] true only when a minimum applies and is not met
      def below_order_minimum?
        shortfall = order_minimum_shortfall
        shortfall.present? && shortfall.positive?
      end

      # Why each line may no longer be ordered as it stands, in the same words
      # add-to-cart used. Empty for a retail buyer, and empty for anyone whose
      # terms have not changed under them since they built the cart.
      #
      # @return [Array<Array(Spree::LineItem, String)>]
      def quantity_rule_violations
        # A placed order is history: its terms were checked when it was
        # placed, and re-reporting them against today's agreement would
        # accuse a completed sale of breaking a rule written after it.
        return [] if staff_initiated? || (is_a?(Spree::Order) && completed?)

        line_items.filter_map do |line_item|
          variant = line_item.variant
          next if variant.nil?

          message = quantity_rules_for(variant).violation_message(line_item.name, line_item.quantity)
          next if message.nil?

          [line_item, message]
        end
      end

      # Resolved once per instance: a cart asks about every line, and the
      # catalog walk is the same walk each time.
      #
      # @return [Spree::Catalogs::ResolveQuantityRules]
      def quantity_rules_resolver
        @quantity_rules_resolver ||= Spree::Catalogs::ResolveQuantityRules.for_purchase(self)
      end

      # Dropped on reload, so a cart whose company or catalog terms changed in
      # the same request resolves again rather than answering from a set that
      # no longer applies.
      def reload(*)
        @quantity_rules_resolver = nil
        remove_instance_variable(:@order_minimum) if defined?(@order_minimum)
        super
      end
    end
  end
end
