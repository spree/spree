module Spree
  module OrdersHelper
    def order_just_completed?
      @order.present? && @order.completed? && session[:checkout_completed].present?
    end
  end
end
