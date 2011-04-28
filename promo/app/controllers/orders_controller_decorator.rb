OrdersController.class_eval do
  after_filter :clear_promotions

  private
  def clear_promotions
    current_order.promotion_credits.destroy_all if current_order
  end

end

