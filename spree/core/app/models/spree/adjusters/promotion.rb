module Spree
  module Adjusters
    # Recomputes all promotion Discount rows for an order from the promotions
    # connected to it (plus any promotions being activated right now, passed as
    # +extra_promotions+). Candidates are computed for every eligible promotion
    # on every recalculation; only applied discounts are persisted — losing
    # candidates are simply not written, so "reinstatement" needs no stored
    # rows. Selection policy is isolated in {#select_applicable} (winner-only
    # in 6.0; 6.1 stacking replaces just that method).
    #
    # Competition groups mirror the legacy semantics: line-level actions
    # compete per line item, fulfillment actions compete per fulfillment, and
    # order-level actions compete order-wide — the order-wide winner is
    # distributed proportionally across line items (largest-remainder over
    # each line's remaining discounted base), so no order-attached rows exist.
    class Promotion < Base
      def initialize(order, extra_promotions: [])
        super(order)
        @extra_promotions = extra_promotions
        @applied_row_ids = []
      end

      def update
        apply_line_item_discounts
        apply_fulfillment_discounts
        apply_order_level_discount
        sync_coupon_promotion_joins
        cleanup_stale_rows
      end

      # @param action [Spree::PromotionAction]
      # @return [Boolean] whether the action currently yields any candidate
      def candidate_for?(action)
        case action.discount_scope
        when :line_item
          order.line_items.any? { |line_item| line_item_candidates(line_item).any? { |c| c[:action].id == action.id } }
        when :fulfillment
          order.fulfillments.any? && eligible_promotions.include?(action.promotion)
        when :order
          order_level_candidates.any? { |c| c[:action].id == action.id }
        else
          false
        end
      end

      private

      attr_reader :extra_promotions

      # THE selection seam: 6.0 is winner-takes-all per competition group.
      # 6.1 stacking replaces this method with a combines_with partition —
      # persistence, clamping and proration below already support multiple
      # applied rows per adjustable.
      def select_applicable(candidates)
        return [] if candidates.empty?

        # Most negative amount wins; ties go to the newest action.
        [candidates.min_by { |candidate| [candidate[:amount], -candidate[:action].id] }]
      end

      def eligible_promotions
        @eligible_promotions ||= begin
          promotions = (order.promotions.includes(:promotion_actions).to_a + extra_promotions + coupon_promotions).uniq(&:id)
          promotions.select { |promotion| promotion.eligible?(order) }
        end
      end

      # The owner's PERSISTED coupon code keeps its promotion in candidacy
      # even before it ever applied — the discount activates on the exact
      # recalculation where the cart first qualifies, and deactivates the
      # same way (Shopify-parity for cart-level discount codes). In-memory
      # assignments deliberately don't participate: unsaved codes belong to
      # the explicit PromotionHandler::Coupon path.
      def coupon_promotions
        return [] unless order.class.respond_to?(:column_names) && order.class.column_names.include?('coupon_code')

        code = order.read_attribute(:coupon_code)
        return [] if code.blank?

        promotion = order.store.promotions.active.with_coupon_code(code)
        return [] if promotion.nil? || promotion.usage_limit_exceeded?(order)

        [promotion]
      end

      # A coupon promotion that produced rows becomes an applied promotion —
      # the join drives the storefront discounts summary and completion-time
      # usage accounting.
      def sync_coupon_promotion_joins
        coupon_promotions.each do |promotion|
          next unless order.discounts.where(promotion_id: promotion.id).exists?

          order.order_promotions.find_or_create_by!(promotion: promotion)
        end
      end

      def discount_actions(scope)
        eligible_promotions.flat_map(&:promotion_actions).select { |action| action.discount_scope == scope }
      end

      def apply_line_item_discounts
        order.line_items.each do |line_item|
          applicable = select_applicable(line_item_candidates(line_item))
          applicable.each do |candidate|
            amount = clamp(candidate[:amount], discountable_base(line_item))
            next if amount.zero?

            persist_discount(line_item, candidate, amount)
          end
        end
      end

      def line_item_candidates(line_item)
        @line_item_candidates ||= {}
        @line_item_candidates[line_item.id] ||= discount_actions(:line_item).filter_map do |action|
          next unless action.promotion.line_item_actionable?(order, line_item)

          amount = action.compute_amount(line_item)
          next if amount.zero?

          candidate(action, amount)
        end
      end

      def apply_fulfillment_discounts
        actions = discount_actions(:fulfillment)
        return if actions.empty?

        order.fulfillments.each do |fulfillment|
          candidates = actions.map { |action| candidate(action, action.compute_amount(fulfillment)) }
          select_applicable(candidates).each do |chosen|
            amount = clamp(chosen[:amount], fulfillment.cost)
            # Free shipping rows persist even at zero amount — row existence
            # is the "this order has free shipping" signal.
            next if amount.zero? && !chosen[:action].persist_at_zero?

            persist_discount(fulfillment, chosen, amount)
          end
        end
      end

      def order_level_candidates
        @order_level_candidates ||= discount_actions(:order).filter_map do |action|
          amount = action.compute_amount(order)
          next if amount.zero?

          candidate(action, amount)
        end
      end

      def apply_order_level_discount
        select_applicable(order_level_candidates).each do |chosen|
          distribute_over_line_items(chosen)
        end
      end

      # Largest-remainder distribution (in cents) of the order-wide winner over
      # each line's remaining discounted base, so shares always sum exactly to
      # the promotion amount and no line goes below zero.
      def distribute_over_line_items(chosen)
        line_items = order.line_items.to_a
        bases = line_items.map { |line_item| [discountable_base(line_item), BigDecimal(0)].max }
        bases_sum = bases.sum
        return if bases_sum <= 0

        total_cents = [chosen[:amount].abs, bases_sum].min * 100
        shares = Spree::Adjusters::LargestRemainder.largest_remainder_shares(total_cents.round, bases)

        line_items.each_with_index do |line_item, index|
          amount = -BigDecimal(shares[index]) / 100
          next if amount.zero?

          persist_discount(line_item, chosen, amount)
        end
      end

      # Combined discounts never push an adjustable's net below zero.
      def clamp(amount, base)
        [amount, -[base, BigDecimal(0)].max].max
      end

      # The adjustable's remaining discounted amount: its own base minus
      # discounts already applied — manual/custom rows plus promotion rows
      # written earlier in this pass. Stale promotion rows from previous
      # passes are excluded (they're about to be cleaned up) so recalculation
      # never compounds against its own output.
      def discountable_base(adjustable)
        base = adjustable.is_a?(Spree::LineItem) ? adjustable.amount : adjustable.cost
        applied = adjustable.discounts.reload.select do |row|
          !row.promotion? || @applied_row_ids.include?(row.id)
        end
        base + applied.sum(&:amount)
      end

      def candidate(action, amount)
        value, value_type = value_snapshot(action)
        {
          action: action,
          promotion: action.promotion,
          amount: amount,
          label: action.send(:label),
          code: action.promotion.code_for_order(order),
          value: value,
          value_type: value_type
        }
      end

      def value_snapshot(action)
        calculator = action.try(:calculator)
        return [nil, nil] unless calculator

        if calculator.respond_to?(:preferred_percent)
          [calculator.preferred_percent, 'percent']
        elsif calculator.respond_to?(:preferred_flat_percent)
          [calculator.preferred_flat_percent, 'percent']
        elsif calculator.respond_to?(:preferred_amount)
          [calculator.preferred_amount, 'flat']
        else
          [nil, nil]
        end
      end

      def persist_discount(adjustable, candidate, amount)
        row = adjustable.discounts.find_or_initialize_by(kind: 'promotion', promotion_action_id: candidate[:action].id)
        row.assign_attributes(
          owner_attributes(adjustable).merge(
            amount: amount,
            label: candidate[:label],
            code: candidate[:code],
            value: candidate[:value],
            value_type: candidate[:value_type],
            promotion: candidate[:promotion]
          )
        )
        row.save!
        @applied_row_ids << row.id
        row
      end

      def owner_attributes(adjustable)
        owner = adjustable.owner
        owner.is_a?(Spree::Order) ? { order: owner, cart: nil } : { cart: owner, order: nil }
      end

      # Everything not written in this pass is stale: losing candidates,
      # promotions that stopped being eligible, and rows whose promotion was
      # deleted (FKs nullified). Manual and custom-kind discounts are not ours.
      def cleanup_stale_rows
        order.discounts.promotion.where.not(id: @applied_row_ids).destroy_all
      end
    end
  end
end
