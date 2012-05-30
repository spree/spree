module Spree
  module Core
    module CurrentOrder

      # This should be overridden by an auth-related extension which would then have the
      # opportunity to associate the new order with the # current user before saving.
      def before_save_new_order
      end

      # This should be overridden by an auth-related extension which would then have the
      # opporutnity to store tokens, etc. in the session # after saving.
      def after_save_new_order
      end

      def last_incomplete_order_of_current_user
      end

      # The current incomplete order from the session for use in cart and during checkout
      def current_order(create_order_if_necessary = false)
        return @current_order if @current_order
        if session[:order_id]
          @current_order = Spree::Order.find_by_id(session[:order_id], :include => :adjustments)
        end

        if @current_order.nil?
          @current_order = last_incomplete_order_of_current_user
        end

        if create_order_if_necessary && (@current_order.nil? || @current_order.completed?)
          @current_order = Spree::Order.new
          before_save_new_order
          @current_order.save!
          after_save_new_order
        end
        session[:order_id] = @current_order ? @current_order.id : nil
        @current_order
      end
    end
  end
end
