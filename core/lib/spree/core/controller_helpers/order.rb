module Spree
  module Core
    module ControllerHelpers
      module Order
        extend ActiveSupport::Concern

        included do
          helper_method :current_order
          helper_method :simple_current_order
        end

        # Used in the link_to_cart helper.
        def simple_current_order
          return @simple_current_order if @simple_current_order

          @simple_current_order = find_order_by_token_or_user

          if @simple_current_order
            @simple_current_order.last_ip_address = ip_address
            return @simple_current_order
          else
            @simple_current_order = Spree::Order.new
          end
        end

        # The current incomplete order from the token for use in cart and during checkout
        def current_order(options = {})
          options[:create_order_if_necessary] ||= false
          options[:includes] ||= true

          if @current_order
            @current_order.last_ip_address = ip_address
            return @current_order
          end

          @current_order = find_order_by_token_or_user(options, true)

          if options[:create_order_if_necessary] && (@current_order.nil? || @current_order.completed?)
            @current_order = Spree::Order.create!(current_order_params)
            @current_order.associate_user! try_spree_current_user if try_spree_current_user
            @current_order.last_ip_address = ip_address
          end

          @current_order
        end

        def associate_user
          @order ||= current_order
          if try_spree_current_user && @order
            @order.associate_user!(try_spree_current_user) if @order.user.blank? || @order.email.blank?
          end
        end

        def set_current_order
          return unless try_spree_current_user && current_order

          orders_scope = try_spree_current_user.orders.
                         incomplete.
                         where.not(id: current_order.id).
                         where(store_id: current_store.id)

          orders_scope.each do |order|
            current_order.merge!(order, try_spree_current_user)
          end
        end

        def ip_address
          request.remote_ip
        end

        private

        def last_incomplete_order(includes = {})
          @last_incomplete_order ||= try_spree_current_user.last_incomplete_spree_order(current_store, includes: includes)
        end

        def current_order_params
          { currency: current_currency, token: cookies.signed[:token], store_id: current_store.id, user_id: try_spree_current_user.try(:id) }
        end

        def find_order_by_token_or_user(options = {}, with_adjustments = false)
          options[:lock] ||= false

          includes = if options[:includes]
                       { line_items: [variant: [:images, :option_values, :product]] }
                     else
                       {}
                     end

          # Find any incomplete orders for the token
          incomplete_orders = Spree::Order.incomplete.includes(includes)

          token_order_params = current_order_params.except(:user_id)
          order = if with_adjustments
                    incomplete_orders.includes(:adjustments).lock(options[:lock]).find_by(token_order_params)
                  else
                    incomplete_orders.lock(options[:lock]).find_by(token_order_params)
                  end

          # Find any incomplete orders for the current user
          order = last_incomplete_order(includes) if order.nil? && try_spree_current_user

          order
        end
      end
    end
  end
end
