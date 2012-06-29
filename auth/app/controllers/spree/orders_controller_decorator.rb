require File.expand_path('../base_controller_decorator', __FILE__)

Spree::OrdersController.class_eval do
  before_filter :check_authorization

  private
    def check_authorization
      session[:access_token] ||= params[:token]
      order = Spree::Order.find_by_number(params[:id]) || current_order

      if order
        authorize! :edit, order, session[:access_token]
      else
        authorize! :create, Spree::Order.new
      end
    end
end
