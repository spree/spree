class CouponCredit < Credit
  named_scope :with_order, :conditions => "order_id IS NOT NULL"

  def calculate_adjustment
    adjustment_source && calculate_coupon_credit
  end

  # Checks if credit is still applicable to order
  # If source of adjustment is credit, it checks if it's still valid
  def applicable?
    adjustment_source && adjustment_source.eligible?(order) && super
  end

  # Calculates credit for the coupon.
  #
  # If coupon amount exceeds the order item_total, credit is adjusted.
  #
  # Always returns negative non positive.
  def calculate_coupon_credit
    return 0 if order.line_items.empty?
    amount = adjustment_source.calculator.compute(order.line_items).abs
    amount = order.item_total if amount > order.item_total
    -1 * amount
  end
end
