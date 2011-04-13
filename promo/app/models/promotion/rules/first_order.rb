class Promotion::Rules::FirstOrder < PromotionRule

  def eligible?(order)
    order.user && order.user.orders.complete.count == 0
  end

end
