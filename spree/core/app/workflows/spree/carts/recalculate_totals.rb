module Spree
  module Carts
    # Money recalculation — item counts, money totals, one update_columns
    # persist. Money ONLY: payment_status/fulfillment_status are written
    # exclusively by Spree::Orders::UpdateStatuses, and completed-order
    # fulfillment repricing belongs to the explicit post-placement edit
    # path, never to a totals refresh.
    #
    # Completed orders are money-frozen one level down: their typed rows
    # (discounts, fees, tax lines) are never regenerated — no promotion
    # competition, no tax estimation — but the denormalized sums are always
    # re-derived from the rows. That makes this the single totals seam for
    # both live checkout math and post-placement edits (the admin
    # tax_lines/discounts/fees endpoints write rows directly, then run
    # this).
    class RecalculateTotals < Spree::Workflow
      hooks :set_tax_line_context

      # Untyped provider extras contributed by set_tax_line_context handlers —
      # anything a specific provider needs that the typed estimate arguments
      # don't carry. Exemptions and the buyer's tax identity are NOT this: they
      # are typed inputs of their own. Nil until the typed rows are regenerated.
      attr_reader :tax_line_context

      # @param cart [Spree::Cart, Spree::Order]
      # @param resum_only [Boolean] re-sum the rows the record already carries
      #   without regenerating them. A placed order is frozen by its own
      #   lifecycle, but an order can also hold rows that must not be
      #   re-derived before it is placed — the seller split moves already-costed
      #   rows onto child orders that are still drafts, and re-running the
      #   promotion and tax engines against one seller's subset would answer a
      #   question the checkout already answered against the whole basket.
      def perform(cart:, resum_only: false)
        super

        step :reset_association_caches
        step :update_item_count
        step :refresh_money_inputs
        step :regenerate_typed_rows unless money_frozen?
        step :fold_typed_rows
        step :refresh_grand_total
        step :persist_totals

        success(cart)
      end

      private

      # An earlier recalculation on this instance may have loaded the
      # associations mid-mutation.
      def reset_association_caches
        return unless cart.persisted?

        cart.association(:line_items).reset
        cart.association(:fulfillments).reset
      end

      def update_item_count
        cart.total_quantity = cart.line_items.sum(:quantity)
      end

      # Two passes: adjusters persist the discounted taxable base first,
      # then tax is estimated on it.
      def regenerate_typed_rows
        Spree.adjusters.each { |adjuster| adjuster.adjust(cart) }
        refresh_discount_and_fee_columns
        @tax_line_context = run_hooks :set_tax_line_context
        cart.tax_provider.estimate(cart, **cart.tax_estimate_inputs, context: tax_line_context)
      end

      # Re-derives the denormalized per-adjustable columns and the record's
      # own sums from the typed rows — safe on frozen orders, where the
      # rows are the source of truth.
      def fold_typed_rows
        refresh_discount_and_fee_columns if money_frozen?
        refresh_tax_columns

        discounts_sum = cart.discounts.reload.sum(&:amount)
        fees = cart.fees.reload.to_a
        tax_sums = cart.tax_lines.reload.group_by(&:included?).transform_values { |lines| lines.sum(&:amount) }

        cart.discount_total = cart.discounts.select(&:promotion?).sum(&:amount)
        cart.fee_total = fees.sum(&:amount)
        cart.included_tax_total = tax_sums.fetch(true, 0)
        cart.additional_tax_total = tax_sums.fetch(false, 0)
        cart.adjustment_total = discounts_sum + cart.fee_total + cart.additional_tax_total

        # The record's own adjustable columns cover order-level rows only:
        # discounts distribute to line items, so fees are the only residents.
        cart.taxable_adjustment_total = 0
        cart.non_taxable_adjustment_total = fees.select(&:order_level?).sum(&:amount)
      end

      # Runs before the adjusters: promotion-rule eligibility (item-total
      # thresholds, free shipping) reads these attributes, so they must
      # reflect the current line items — not the previous recalculation.
      def refresh_money_inputs
        cart.payment_total = paid_so_far
        cart.item_total = cart.line_items.to_a.sum(&:amount)
        cart.delivery_total = cart.fulfillments.to_a.sum(&:cost)
      end

      # What has actually been paid towards this record.
      #
      # An order placed in a split checkout owns no payments — the customer
      # paid once, against the group — so its position is the sum of its
      # shares. Reading its own payments would persist nothing paid and report
      # the whole total as outstanding.
      #
      # @return [BigDecimal]
      def paid_so_far
        if cart.is_a?(Spree::Order) && cart.grouped?
          return cart.payment_splits.to_a.sum(&:net_captured_amount)
        end

        cart.payments.completed.includes(:refunds).inject(0) do |sum, payment|
          sum + payment.amount - payment.refunds.sum(:amount)
        end
      end

      def refresh_grand_total
        cart.total = cart.item_total + cart.delivery_total + cart.adjustment_total
      end

      def persist_totals
        columns = {
          item_total: cart.item_total,
          total_quantity: cart.total_quantity,
          adjustment_total: cart.adjustment_total,
          included_tax_total: cart.included_tax_total,
          additional_tax_total: cart.additional_tax_total,
          taxable_adjustment_total: cart.taxable_adjustment_total,
          non_taxable_adjustment_total: cart.non_taxable_adjustment_total,
          payment_total: cart.payment_total,
          delivery_total: cart.delivery_total,
          discount_total: cart.discount_total,
          fee_total: cart.fee_total,
          total: cart.total,
          updated_at: Time.current
        }
        if cart.is_a?(Spree::Order)
          columns[:payment_status] = cart.payment_status
          columns[:fulfillment_status] = cart.fulfillment_status
        end
        cart.update_columns(columns)
      end

      def money_frozen?
        resum_only || (cart.is_a?(Spree::Order) && cart.completed?)
      end

      # Pass one of the two-pass recalculation: persist per-adjustable
      # discount and fee sums so the tax provider estimates on the
      # discounted base.
      def refresh_discount_and_fee_columns
        discounts = cart.discounts.reload.to_a
        fees = cart.fees.reload.to_a

        each_adjustable do |adjustable, key|
          rows = discounts.select { |row| row.public_send(key) == adjustable.id }
          fee_rows = fees.select { |row| row.public_send(key) == adjustable.id }

          update_adjustable_columns(
            adjustable,
            taxable_adjustment_total: rows.sum(&:amount),
            non_taxable_adjustment_total: fee_rows.sum(&:amount),
            discount_total: rows.select(&:promotion?).sum(&:amount)
          )
        end
      end

      # Pass two: fold the freshly estimated (or frozen) tax rows into the
      # per-adjustable columns.
      def refresh_tax_columns
        tax_lines = cart.tax_lines.reload.to_a

        each_adjustable do |adjustable, key|
          rows = tax_lines.select { |row| row.public_send(key) == adjustable.id }
          included, additional = rows.partition(&:included?)

          update_adjustable_columns(
            adjustable,
            included_tax_total: included.sum(&:amount),
            additional_tax_total: additional.sum(&:amount),
            adjustment_total: adjustable.taxable_adjustment_total +
              adjustable.non_taxable_adjustment_total +
              additional.sum(&:amount)
          )
        end
      end

      def each_adjustable
        cart.line_items.each { |line_item| yield line_item, :line_item_id }
        cart.fulfillments.each { |fulfillment| yield fulfillment, :fulfillment_id }
      end

      def update_adjustable_columns(adjustable, attributes)
        return unless adjustable.persisted?
        return if attributes.all? { |key, value| adjustable.public_send(key) == value }

        adjustable.update_columns(attributes.merge(updated_at: Time.current))
      end
    end
  end
end
