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

          return @simple_current_order if @simple_current_order

          @simple_current_order = find_order_by_token_or_user(false)

          if @simple_current_order
            @simple_current_order.last_ip_address = ip_address
            @simple_current_order
          else
            @simple_current_order = Spree::Order.new
          end
        end

        # The current incomplete order from the guest_token or users last incomplete carts
        #
        # @return [Spree::Order]
        #   if current order is recoverable from token or history
        #
        # @return [nil]
        def current_order
          return @current_order if defined?(@current_order)

          @current_order = find_order_by_token_or_user(true).try do |order|
            order.last_ip_address = ip_address
            # See issue #3346 for reasons why this line is here
            order.created_by ||= try_spree_current_user
            order
          end
        end

        # The current order representing cart state
        #
        # Order is not persisted in case cart is pristine / empty.
        #
        # @return [Spree::Order]
        def cart_order
          return current_order if current_order
          @cart_order ||= Spree::Order.new(
            current_order_params.merge(
              created_by:      try_spree_current_user,
              last_ip_address: ip_address
            )
          )
        end

        def associate_user
          @order ||= current_order

          if try_spree_current_user && @order
            @order.associate_user!(try_spree_current_user) if @order.user.blank? || @order.email.blank?
          end
        end

        def set_current_order
          if try_spree_current_user && current_order
            try_spree_current_user.orders.incomplete.where('id != ?', current_order.id).each do |order|
              current_order.merge!(order, try_spree_current_user)
            end
          end
        end

        def current_currency
          Spree::Config[:currency]
        end

        def ip_address
          request.remote_ip
        end

        private

        def current_order_params
          {
            currency:    current_currency,
            guest_token: cookies.signed[:guest_token],
            user_id:     try_spree_current_user.try(:id)
          }
        end

        def find_order_by_token_or_user(lock)
          # Find any incomplete orders for the guest_token
          order = Spree::Order.incomplete.includes(:all_adjustments).lock(lock).find_by(current_order_params)

          # Find any incomplete orders for the current user
          order ||= if try_spree_current_user
            try_spree_current_user.incomplete_spree_orders.lock(lock).first
          end
        end

      end
    end
  end
end
