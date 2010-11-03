module Spree
  module CurrentOrder

    # This should be overridden by an auth-related extension which would then have the opporutnity to associate the new order with the
    # current user before saving.
    def before_save_new_order
    end

    # The current incomplete order from the session for use in cart and during checkout
    def current_order(create_order_if_necessary = false)
      return @current_order if @current_order
      @current_order ||= Order.find_by_id(session[:order_id], :include => :adjustments)
      if create_order_if_necessary and (@current_order.nil? or @current_order.completed?)
        @current_order = Order.new
        before_save_new_order
        @current_order.save!
      end
      session[:order_id] = @current_order ? @current_order.id : nil
      @current_order
    end
  end
end
