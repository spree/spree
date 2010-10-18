OrdersController.class_eval do
  after_filter :store_guest, :only => :populate
  before_filter :associate_user, :only => :edit
  before_filter :check_authorization

  private
  def store_guest
    return if current_user
    session[:guest_token] ||= @order.user.persistence_token
  end

  def check_authorization
    session[:guest_token] ||= params[:token]
    order = current_order || Order.find_by_number(params[:id])
    if order
      authorize! :edit, order
    else
      authorize! :create, Order
    end
  end

  # Associate the user with the order when appropriate.  Orders that are created after a user has registered/authenticated need
  # to be associated correctly with this user (we can't rely on the authentication process after the fact.)
  def associate_user
    order = current_order
    return unless order.anonymous? and current_user
    order.associate_user!(current_user) #if session[:guest_token] == @order.user.persistence_token
  end

end
