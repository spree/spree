class CouponCredit < Credit
  def calculate_adjustment
    adjustment_source && calculate_coupon_credit
  end

  # Checks if credit is still applicable to order
  # If source of adjustment is credit, it checks if it's still valid
  def applicable?
    adjustment_source && adjustment_source.eligible?(order) && super
  end

  def calculate_coupon_credit
    return 0 if order.line_items.empty?
    amount = adjustment_source.calculator.compute(order)
    amount = order.item_total if amount > order.item_total
    amount
  end
end