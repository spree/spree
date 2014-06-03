module Spree
  module Core
    module ControllerHelpers
      module Order
        extend ActiveSupport::Concern

        included do
          before_filter :set_current_order

          helper_method :current_currency
          helper_method :current_order
          helper_method :simple_current_order
        end

        # Used in the link_to_cart helper.
        def simple_current_order
          @order ||= Spree::Order.find_by(completed_at: nil, currency: current_currency, guest_token: cookies.signed[:guest_token])
        end

        # The current incomplete order from the guest_token for use in cart and during checkout
        def current_order(options = {})
          options[:create_order_if_necessary] ||= false
          options[:lock] ||= false

          return @current_order if @current_order

          # Find any incomplete orders for the guest_token
          @current_order = Spree::Order.includes(:adjustments).lock(options[:lock]).find_by(completed_at: nil, currency: current_currency, guest_token: cookies.signed[:guest_token])

          if options[:create_order_if_necessary] and (@current_order.nil? or @current_order.completed?)
            @current_order = Spree::Order.new(currency: current_currency, guest_token: cookies.signed[:guest_token])
            @current_order.user ||= try_spree_current_user
            # See issue #3346 for reasons why this line is here
            @current_order.created_by ||= try_spree_current_user
            @current_order.save!
          end

          if @current_order
            @current_order.last_ip_address = ip_address
            return @current_order
          end
        end

        def associate_user
          @order ||= current_order
          if try_spree_current_user && @order
            @order.associate_user!(try_spree_current_user) if @order.user.blank? || @order.email.blank?
          end
        end

        def set_current_order
          if user = try_spree_current_user
            last_incomplete_order = user.last_incomplete_spree_order
            if last_incomplete_order
              cookies.permanent.signed[:guest_token] = last_incomplete_order.guest_token
            elsif current_order && last_incomplete_order && current_order != last_incomplete_order
              current_order.merge!(last_incomplete_order, user)
            end
          end
        end

        def current_currency
          Spree::Config[:currency]
        end

        def ip_address
          request.remote_ip
        end
      end
    end
  end
end
