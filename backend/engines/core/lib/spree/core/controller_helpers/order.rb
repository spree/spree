module Spree
  module Core
    module ControllerHelpers
      module Order
        extend ActiveSupport::Concern

        included do
          if defined?(helper_method)
            helper_method :current_order
            helper_method :simple_current_order
          end
        end

        def order_token
          @order_token ||= cookies.signed[:token] || params[:order_token]
        end

        # Used in the link_to_cart helper.
        def simple_current_order
          return @simple_current_order if @simple_current_order

          @simple_current_order = find_order_by_token_or_user

          if @simple_current_order
            @simple_current_order.last_ip_address = ip_address
            return @simple_current_order
          else
            @simple_current_order = current_store.orders.new
          end
        end

        # The current incomplete order from the token for use in cart and during checkout
        def current_order(options = {})
          options[:create_order_if_necessary] ||= false
          options[:includes] ||= false

          if @current_order
            @current_order.last_ip_address = ip_address
            return @current_order
          end

          @current_order = find_order_by_token_or_user(options, false)

          if options[:create_order_if_necessary] && (@current_order.nil? || @current_order.completed?)
            @current_order = current_store.orders.create!(current_order_params.except(:token))
            @current_order.associate_user! try_spree_current_user if try_spree_current_user
            @current_order.last_ip_address = ip_address

            create_token_cookie(@current_order.token)
          end

          # There is some edge case where the order doesn't have a token.
          # but can't reproduce it. So let's generate one on the fly in that case.
          @current_order.regenerate_token if @current_order && @current_order.token.blank?

          create_token_cookie(@current_order&.token || current_order_params[:token] || params[:token]) if create_cookie_from_token?

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

          orders_scope = user_orders_scope

          orders_to_merge = orders_scope.limit(10)
          order_ids_to_delete = orders_scope.ids - orders_to_merge.ids

          orders_scope_exists = orders_scope.exists?

          if orders_scope.exists?
            ActiveRecord::Base.connected_to(role: :writing) do
              orders_to_merge.find_each do |order|
                current_order.merge!(order, try_spree_current_user)
              end

              Spree::Order.where(id: order_ids_to_delete).find_each do |order|
                Rails.logger.error("Failed to destroy order #{order.id} while merging") unless order.destroy
              end
            end
          end

          orders_scope_exists
        end

        def ip_address
          request.remote_ip
        end

        private

        def user_orders_scope
          try_spree_current_user.orders.
            incomplete.
            not_canceled.
            where.not(id: current_order.id).
            where(store_id: current_store.id)
        end

        def create_cookie_from_token?
          cookies.signed[:token].blank? &&
            (current_order_params[:token].present? || params[:token].present?)
        end

        def checkout_complete_path?
          request.path == spree.checkout_complete_path(current_order_params[:token] || params[:token])
        end

        def create_token_cookie(token)
          cookies.signed[:token] = {
            value: token,
            expires: 90.days.from_now,
            secure: Rails.configuration.force_ssl || Rails.application.config.ssl_options[:secure_cookies],
            domain: cookie_domain_without_port,
            httponly: true
          }
        end

        def cookie_domain_without_port
          domain = current_store.url_or_custom_domain
          return nil if domain.blank?

          # Remove port from domain (e.g., "localhost:3000" -> "localhost")
          # Cookies don't support port numbers in the domain attribute
          domain.split(':').first
        end

        def last_incomplete_order(includes = {})
          @last_incomplete_order ||= try_spree_current_user.last_incomplete_spree_order(current_store, includes: includes)
        end

        def current_order_params
          @current_order_params ||= { currency: current_currency, token: order_token, user_id: try_spree_current_user.try(:id) }
        end

        def find_order_by_token_or_user(options = {}, with_adjustments = false)
          return nil if try_spree_current_user.nil? && order_token.blank?

          options[:lock] ||= false

          includes = options[:includes] ? order_includes : {}

          # Find any incomplete orders for the token
          incomplete_orders = current_store.orders.incomplete.not_canceled.includes(includes)

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

        def order_includes
          {
            line_items: {
              variant: [
                :images,
                :prices,
                :default_price,
                :stock_items,
                :stock_locations,
                { option_values: :option_type },
                { stock_items: :stock_location },
                { product: :master }
              ]
            }
          }
        end
      end
    end
  end
end
