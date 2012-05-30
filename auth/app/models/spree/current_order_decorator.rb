Spree::Core::CurrentOrder.module_eval do
  # Associate the new order with the currently authenticated user before saving
  def before_save_new_order
    @current_order.user ||= current_user
  end

  def after_save_new_order
    # make sure the user has permission to access the order (if they are a guest)
    return if current_user
    session[:access_token] = @current_order.token
  end

  def last_incomplete_order_of_current_user
    return current_user.incompleted_orders.last if current_user
  end
end
