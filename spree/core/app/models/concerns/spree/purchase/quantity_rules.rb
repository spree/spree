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

      # Every line whose quantity no longer satisfies the buyer's rules,
      # paired with the rule it breaks. Empty for a retail buyer, and empty
      # for anyone who has not had their terms changed under them.
      #
      # @return [Array<Array(Spree::LineItem, Spree::QuantityRule)>]
      def line_items_violating_quantity_rules
        resolver = quantity_rules_resolver

        line_items.filter_map do |line_item|
          variant = line_item.variant
          next if variant.nil?

          rule = resolver.call(variant)
          next if rule.satisfied_by?(line_item.quantity)

          [line_item, rule]
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
