Spree::Order.class_eval do

  attr_accessible :coupon_code
  attr_accessor   :coupon_code

  # Tells us if there if the specified promotion is already associated with the order
  # regardless of whether or not its currently eligible.  Useful because generally
  # you would only want a promotion to apply to order no more than once.
  def promotion_credit_exists?(promotion)
    !! adjustments.promotion.reload.detect { |credit| credit.originator.promotion.id == promotion.id }
  end

  def promo_total
    adjustments.eligible.promotion.pluck(:amount).sum
  end

  def coupon_code_applied?
    adjustments.promotion.eligible.detect do |p|
      Spree::Promotion.normalize_coupon_code(p.originator.promotion.code) == normalized_coupon_code
    end.present?
  end

  def find_adjustment_for_coupon_code
    adjustments.promotion.detect do |p|
      Spree::Promotion.normalize_coupon_code(p.originator.promotion.code) == normalized_coupon_code
    end
  end

  def find_promo_for_coupon_code
    Spree::Promotion.where("LOWER(code) = '#{normalized_coupon_code}'").first
  end

  def normalized_coupon_code
    Spree::Promotion.normalize_coupon_code(coupon_code)
  end
end
