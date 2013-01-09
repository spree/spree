Spree::Order.class_eval do
  attr_accessible :coupon_code
  attr_reader :coupon_code

  def coupon_code=(code)
    @coupon_code = code.strip.downcase rescue nil
  end

  # Tells us if there if the specified promotion is already associated with the order
  # regardless of whether or not its currently eligible.  Useful because generally
  # you would only want a promotion to apply to order no more than once.
  def promotion_credit_exists?(promotion)
    !! adjustments.promotion.reload.detect { |credit| credit.originator.promotion.id == promotion.id }
  end

  def promo_total
    adjustments.eligible.promotion.map(&:amount).sum
  end
end
