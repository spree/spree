OrdersController.class_eval do
  after_filter :associate_user, :only => :populate

  private
  def associate_user
    return if current_user
    session[:guest_token] ||= @order.token
  end
end