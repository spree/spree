class Spree::Promotion::Rules::FirstOrder < Spree::PromotionRule
  def eligible?(order, options = {})
    order.user && order.user.orders.complete.count == 0
  end
end
