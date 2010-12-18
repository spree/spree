Spree::CurrentOrder.module_eval do

  # Associate the new order with the currently authenticated user before saving
  def before_save_new_order
    @current_order.user ||= current_user
  end

end
