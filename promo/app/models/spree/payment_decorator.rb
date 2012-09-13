Spree::Payment.class_eval do
  alias_method :old_gateway_options, :gateway_options
  def gateway_options
    options = old_gateway_options
    options.merge!({ :discount => order.promo_total * 100 })
  end
end
