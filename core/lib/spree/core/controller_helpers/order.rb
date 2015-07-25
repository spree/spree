module Spree
  module Core
    module ControllerHelpers
      module Order
        extend ActiveSupport::Concern

        included do
          before_filter :set_current_order

          helper_method :current_order
        end

        # The current incomplete order from the guest_token or users last incomplete carts
        #
        # @return [Spree::Order]
        #   if current order is recoverable from token or history
        #
        # @return [nil]
        def current_order
          return @current_order if defined?(@current_order)
          @current_order = find_order_by_token_or_user.try do |order|
            order.last_ip_address = ip_address
            order
          end
        end

        # The current order representing cart state
        #
        # Order is not persisted in case cart is pristine / empty.
        #
        # @return [Spree::Order]
        def cart_order
          @cart_order ||= current_order || Spree::Order.new(
            store:           current_store,
            user:            try_spree_current_user,
            created_by:      try_spree_current_user,
            last_ip_address: ip_address,
            currency:        current_currency,
            guest_token:     guest_token
          )
        end

        def associate_user
          @order ||= current_order
          if try_spree_current_user && @order
            @order.associate_user!(try_spree_current_user) if @order.user.blank? || @order.email.blank?
          end
        end

        def set_current_order
          current_order if try_spree_current_user
        end

        def current_currency
          Config[:currency]
        end

        def ip_address
          request.remote_ip
        end

        private

        def guest_token
          cookies.signed[:guest_token].presence
        end

        def find_order_by_token_or_user
          user = try_spree_current_user

          # Merge all incomplete orders
          order = merge_orders(user.orders) if user

          # Merge all anonymous orders
          order = merge_orders(anonymous_orders, order) if guest_token

          # Associate the user to the order
          order.try(:associate_user!, user) if user

          order
        end

        def anonymous_orders
          Spree::Order.where(guest_token: guest_token, user_id: nil)
        end

        def merge_orders(orders, other = nil)
          orders.
            incomplete.
            where(currency: current_currency).
            includes(:all_adjustments).
            lock.
            reduce(*other, :merge!)
        end
      end
    end
  end
end
