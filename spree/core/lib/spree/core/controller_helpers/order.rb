module Spree
  module Core
    module ControllerHelpers
      module Order
        extend ActiveSupport::Concern

        included do
          if defined?(helper_method)
            helper_method :current_order
          end
        end

        def order_token
          @order_token ||= cookies.signed[:token] || params[:order_token]
        end

        # The current incomplete cart from the token — the checkout owner
        # since the cart/order split. The name stays for compatibility;
        # Wave 6 renames the storefront surface to current_cart.
        def current_order(options = {})
          options[:create_order_if_necessary] ||= false
          options[:includes] ||= false

          if @current_order
            @current_order.last_ip_address = ip_address
            return @current_order
          end

          @current_order = find_order_by_token_or_user(options, false)

          if options[:create_order_if_necessary] && (@current_order.nil? || @current_order.completed?)
            result = Spree::Carts::Create.call(params: {
              store: current_store,
              currency: current_currency,
              user: try_spree_current_user
            })
            @current_order = result.value
            @current_order.update_columns(last_ip_address: ip_address)

            create_token_cookie(@current_order.token)
          end

          # There is some edge case where the cart doesn't have a token.
          # but can't reproduce it. So let's generate one on the fly in that case.
          @current_order.regenerate_token if @current_order && @current_order.token.blank?

          create_token_cookie(@current_order&.token || current_order_params[:token] || params[:token]) if create_cookie_from_token?

          @current_order
        end
        alias current_cart current_order

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
          Spree::Cart.where(customer_id: try_spree_current_user.id).
            incomplete.
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

          # Find any incomplete carts for the token
          incomplete_carts = current_store.carts.incomplete.includes(includes)

          token_order_params = current_order_params.except(:user_id)
          cart = if with_adjustments
                   incomplete_carts.includes(:discounts, :fees).lock(options[:lock]).find_by(token_order_params)
                 else
                   incomplete_carts.lock(options[:lock]).find_by(token_order_params)
                 end

          # Find any incomplete carts for the current user
          cart = last_incomplete_cart(includes) if cart.nil? && try_spree_current_user

          cart
        end

        def last_incomplete_cart(includes = {})
          @last_incomplete_cart ||= Spree::Cart.where(customer_id: try_spree_current_user.id, store_id: current_store.id).
            incomplete.
            order(created_at: :desc).
            includes(includes).
            first
        end

        def order_includes
          variant_includes = [
            :images,
            :prices,
            :stock_items,
            :stock_locations,
            { option_values: :option_type },
            { stock_items: :stock_location },
            { product: :default_variant }
          ]

          {
            line_items: {
              variant: variant_includes
            }
          }
        end
      end
    end
  end
end
