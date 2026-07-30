module Spree
  # Recalculates a cart: same typed-adjustment two-pass as OrderUpdater
  # (adjusters, then the tax provider) but persisting the cart's own column
  # set — carts carry no payment/fulfillment status columns and are never
  # frozen (completion copies them into an immutable order instead).
  class CartUpdater < OrderUpdater
    alias cart order

    def update_payment_total
      cart.payment_total = payments.completed.includes(:refunds).inject(0) { |sum, payment| sum + payment.amount - payment.refunds.sum(:amount) }
    end

    def persist_totals
      cart.update_columns(
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
      )
    end

    # Carts have no completion freeze — they are recalculated until the
    # moment Carts::Complete copies them into an order.
    def recalculate_adjustments
      Spree.adjusters.each { |adjuster| adjuster.adjust(cart) }
      send(:refresh_discount_and_fee_columns)
      Spree.tax_provider.estimate(cart)
      send(:refresh_tax_columns)
    end

    def update_adjustment_total
      recalculate_adjustments

      discounts_sum = cart.discounts.reload.sum(&:amount)
      cart_fees = cart.fees.reload.to_a
      tax_sums = cart.tax_lines.reload.group_by(&:included?).transform_values { |lines| lines.sum(&:amount) }

      cart.discount_total = cart.discounts.select(&:promotion?).sum(&:amount)
      cart.fee_total = cart_fees.sum(&:amount)
      cart.included_tax_total = tax_sums.fetch(true, 0)
      cart.additional_tax_total = tax_sums.fetch(false, 0)
      cart.adjustment_total = discounts_sum + cart.fee_total + cart.additional_tax_total
      cart.taxable_adjustment_total = 0
      cart.non_taxable_adjustment_total = cart_fees.select(&:order_level?).sum(&:amount)

      update_order_total
    end
  end
end
