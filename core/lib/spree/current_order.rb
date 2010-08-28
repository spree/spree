module Spree
  module CurrentOrder
    # The current incomplete order from the session for use in cart and during checkout
    def current_order(create_order_if_necessary = false)
      return @current_order if @current_order
      @current_order ||= Order.find_by_id(session[:order_id], :include => :adjustments)
      if create_order_if_necessary and (@current_order.nil? or @current_order.complete?)
        @current_order = Order.create
      end
      session[:order_id] = @current_order ? @current_order.id : nil
      @current_order
    end
  end
end