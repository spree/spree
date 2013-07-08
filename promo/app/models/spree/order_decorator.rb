Spree::Order.class_eval do
  attr_accessible :coupon_code

  def coupon_code
    formatted_coupon_code(@coupon_code)
  end

  def coupon_code=(code)
    @coupon_code = formatted_coupon_code(code)
  end

  # Tells us if there if the specified promotion is already associated with the order
  # regardless of whether or not its currently eligible.  Useful because generally
  # you would only want a promotion to apply to order no more than once.
  def promotion_credit_exists?(promotion)
    !! adjustments.promotion.reload.detect { |credit| credit.originator.promotion.id == promotion.id }
  end

  def promo_total
    adjustments.eligible.promotion.pluck(:amount).sum
  end

  private

  def formatted_coupon_code(code)
    code.strip rescue nil
  end
end
