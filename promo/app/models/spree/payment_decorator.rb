Spree::Payment.class_eval do
  def promo_total
    order.promo_total * 100
  end
end
