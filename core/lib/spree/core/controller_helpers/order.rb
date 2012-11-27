module Spree
  module Core
    module ControllerHelpers
      module Order
        def self.included(base)
          base.class_eval do
            helper_method :current_order
            before_filter :set_current_order
          end
        end

        # This should be overridden by an auth-related extension which would then have the
        # opportunity to associate the new order with the # current user before saving.
        def before_save_new_order
        end

        # This should be overridden by an auth-related extension which would then have the
        # opporutnity to store tokens, etc. in the session # after saving.
        def after_save_new_order
        end

        # The current incomplete order from the session for use in cart and during checkout
        def current_order(create_order_if_necessary = false)
          return @current_order if @current_order
          if session[:order_id]
            current_order = Spree::Order.find_by_id_and_currency(session[:order_id], current_currency, :include => :adjustments)
            @current_order = current_order unless current_order.try(:completed?)
          end
          if create_order_if_necessary and (@current_order.nil? or @current_order.completed?)
            @current_order = Spree::Order.new(currency: current_currency)
            before_save_new_order
            @current_order.save!
            after_save_new_order
          end
          session[:order_id] = @current_order ? @current_order.id : nil
          @current_order
        end

        def associate_user
          @order ||= current_order
          if try_spree_current_user && @order
            if @order.user.blank? || @order.email.blank?
              @order.associate_user!(try_spree_current_user)
            end
          end

          # This will trigger any "first order" promotions to be triggered
          # Assuming of course that this session variable was set correctly in
          # the authentication provider's registrations controller
          if session[:spree_user_signup]
            fire_event('spree.user.signup', :user => try_spree_current_user, :order => current_order(true))
          end

          session[:guest_token] = nil
          session[:spree_user_signup] = nil
        end

        def set_current_order
          if user = try_spree_current_user
            last_incomplete_order = user.last_incomplete_spree_order
            if session[:order_id].nil? && last_incomplete_order
              session[:order_id] = last_incomplete_order.id
            elsif current_order && last_incomplete_order && current_order != last_incomplete_order
              current_order.merge!(last_incomplete_order)
            end
          end
        end
      end
    end
  end
end
