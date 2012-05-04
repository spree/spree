Spree::Admin::OrdersController.class_eval do
  before_filter :check_authorization

  private
    def check_authorization
      load_order
      session[:access_token] ||= params[:token]

      resource = @order || Spree::Order.new
      action = params[:action].to_sym

      authorize! action, resource, session[:access_token]
    end
end
