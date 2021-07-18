module Spree
  module Api
    module V2
      module Platform
        class OrdersController < ResourceController
          include Spree::Api::V2::Storefront::OrderConcern

          ORDER_WRITE_ACTIONS = %i[create update destroy advance
                                   next add_item complete remove_line_item]

          before_action -> { doorkeeper_authorize! :write, :admin }, only: ORDER_WRITE_ACTIONS
          before_action :load_order_with_lock, only: %i[next advance complete update
                                                        add_item empty remove_line_item
                                                        apply_coupon_code set_quantity
                                                        remove_coupon_code approve]

          def create
            spree_authorize! :create, Spree::Order
            set_order_currency
            load_user

            order_params = {
              user: @user,
              store: current_store,
              currency: @currency
            }

            order = create_service.call(order_params).value

            render_serialized_payload(201) { serialize_resource(order) }
          end

          def next
            spree_authorize! :update, @order

            result = next_service.call(order: @order)

            render_order(result)
          end

          def advance
            spree_authorize! :update, @order

            result = advance_service.call(order: @order)

            render_order(result)
          end

          def complete
            spree_authorize! :update, @order

            result = complete_service.call(order: @order)

            render_order(result)
          end

          def approve
            spree_authorize! :update, @order
            @order.approved_by(spree_current_user)

            render_serialized_payload { serialize_resource(@order) }
          end

          def empty
            spree_authorize! :update, @order

            @order.empty!

            render_serialized_payload { serialize_resource(@order) }
          end

          def update
            spree_authorize! :update, @order

            result = update_service.call(
              order: @order,
              params: params,
              # defined in https://github.com/spree/spree/blob/master/core/lib/spree/core/controller_helpers/strong_parameters.rb#L19
              permitted_attributes: permitted_checkout_attributes,
              request_env: request.headers.env
            )

            render_order(result)
          end

          def apply_coupon_code
            spree_authorize! :update, @order

            @order.coupon_code = params[:coupon_code]
            result = coupon_handler.new(@order).apply

            if result.error.blank?
              render_serialized_payload { serialize_resource(@order) }
            else
              render_error_payload(result.error)
            end
          end

          def remove_coupon_code
            spree_authorize! :update, @order

            coupon_codes = select_coupon_codes

            return render_error_payload(Spree.t('v2.cart.no_coupon_code', scope: 'api')) if coupon_codes.empty?

            result_errors = coupon_codes.count > 1 ? select_errors(coupon_codes) : select_error(coupon_codes)

            if result_errors.blank?
              render_serialized_payload { serialize_resource(@order) }
            else
              render_error_payload(result_errors)
            end
          end

          protected

          def resource
            @resource ||= scope.find_by!(number: params[:id])
          end

          private

          def model_class
            Spree::Order
          end

          def scope_includes
            [:line_items]
          end

          def load_order(lock: false)
            @order = Spree::Order.lock(lock).find_by!(number: params[:id])
          end

          def load_order_with_lock
            load_order(lock: true)
          end

          def spree_current_order
            @spree_current_order ||= @order
          end

          def load_variant
            @variant = Spree::Variant.find(params[:variant_id])
          end

          def load_user
            @user = if params[:user_id]
                      Spree::User.find(params[:user_id])
                    end
          end

          def line_item
            @line_item ||= @order.line_items.find(params[:line_item_id])
          end

          def set_order_currency
            @currency = if params[:currency] && current_store.supported_currencies_list.include?(params[:currency])
                          params[:currency]
                        else
                          current_currency
                        end
          end

          def render_error_item_quantity
            render json: { error: I18n.t(:wrong_quantity, scope: 'spree.api.v2.cart') }, status: 422
          end

          def create_service
            Spree::Api::Dependencies.platform_order_create_service.constantize
          end

          def add_item_service
            Spree::Api::Dependencies.platform_order_add_item_service.constantize
          end

          def remove_line_item_service
            Spree::Api::Dependencies.platform_order_remove_line_item_service.constantize
          end

          def next_service
            Spree::Api::Dependencies.platform_order_next_service.constantize
          end

          def advance_service
            Spree::Api::Dependencies.platform_order_advance_service.constantize
          end

          def add_store_credit_service
            Spree::Api::Dependencies.platform_order_add_store_credit_service.constantize
          end

          def remove_store_credit_service
            Spree::Api::Dependencies.platform_order_remove_store_credit_service.constantize
          end

          def complete_service
            Spree::Api::Dependencies.platform_order_complete_service.constantize
          end

          def update_service
            Spree::Api::Dependencies.platform_order_update_service.constantize
          end

          def set_item_quantity_service
            Spree::Api::Dependencies.platform_order_set_item_quantity_service.constantize
          end

          def coupon_handler
            Spree::Api::Dependencies.platform_coupon_handler.constantize
          end

          def select_coupon_codes
            params[:coupon_code].present? ? [params[:coupon_code]] : check_coupon_codes
          end

          def check_coupon_codes
            spree_current_order.promotions.coupons.map(&:code)
          end

          def select_error(coupon_codes)
            result = coupon_handler.new(spree_current_order).remove(coupon_codes.first)
            result.error
          end

          def select_errors(coupon_codes)
            results = []
            coupon_codes.each do |coupon_code|
              results << coupon_handler.new(spree_current_order).remove(coupon_code)
            end

            results.select(&:error)
          end
        end
      end
    end
  end
end
