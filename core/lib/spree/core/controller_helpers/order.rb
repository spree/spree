module Spree
  module Core
    module ControllerHelpers
      module Order
        extend ActiveSupport::Concern

        PG_LOCK_NOT_AVAILABLE = 'PG::LockNotAvailable:'.freeze

        included do
          before_filter :set_current_order

          helper_method :current_currency
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
            current_order_params.merge(
              created_by:      try_spree_current_user,
              last_ip_address: ip_address
            )
          )
        end

        def associate_user
          @order ||= current_order
          if @order && (@order.user.nil? || @order.email.blank?)
            @order.associate_user!(try_spree_current_user)
          end
        end

        def set_current_order
          return unless try_spree_current_user && current_order

          try_spree_current_user
            .incomplete_spree_orders
            .lock
            .where.not(id: current_order)
            .each(&current_order.method(:merge!))
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

        def find_order_by_token_or_user
          user = try_spree_current_user

          # Merge all incomplete orders
          order = merge_orders(user.incomplete_spree_orders) if user

          # Merge all anonymous orders
          if current_order_params[:guest_token].present?
            order = merge_orders(anonymous_orders, order)
          end

          # Associate the user to the order
          order.try(:associate_user!, user) if user

          order
        end

        def anonymous_orders
          Spree::Order.incomplete
            .where(current_order_params.merge(user_id: nil))
        end

        def merge_orders(orders, other = nil)
          orders.includes(:all_adjustments).lock.reduce(*other, :merge!)
        rescue ActiveRecord::StatementInvalid => exception
          if exception.message.start_with?(PG_LOCK_NOT_AVAILABLE)
            fail Spree::Order::OrderBusyError
          end

          raise
        end

      end
    end
  end
end
