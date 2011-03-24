OrdersController.class_eval do
  before_filter :check_authorization

  private

  def check_authorization
    session[:access_token] ||= params[:token]
    order = current_order || Order.where(:number => params[:id]).first

    if order
      authorize! :edit, order, session[:access_token]
    else
      authorize! :create, Order
    end
  end

end
