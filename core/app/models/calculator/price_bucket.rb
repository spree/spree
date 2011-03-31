class Calculator::PriceBucket < Calculator
  preference :minimal_amount, :decimal, :default => 0
  preference :normal_amount, :decimal, :default => 0
  preference :discount_amount, :decimal, :default => 0

  def self.description
    I18n.t("price_bucket")
  end

  def self.register
    super
    #Promotion.register_calculator(self)
    ShippingMethod.register_calculator(self)
  end

  # as object we always get line items, as calculable we have Coupon, ShippingMethod
  def compute(object)
    # if object.is_a?(Array)
    #   base = object.map{ |o| o.respond_to?(:amount) ? o.amount : o.to_d }.sum
    # else
    #   base = object.respond_to?(:amount) ? object.amount : object.to_d
    # end
    ##
    # below patch solves to_d bug seen when using this bucket
    # what is this to_d method anyway
    # Thanks for Fernando for the fix
    # http://groups.google.com/group/spree-user/browse_thread/thread/873fbcbda0bc584f
    base = object.line_items.inject(0) {|sum, li| sum += li.amount }
    ##
    if base >= self.preferred_minimal_amount
      self.preferred_normal_amount
    else
      self.preferred_discount_amount
    end
  end
end
