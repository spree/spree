module Spree
  module Api
    module V2
      module Storefront
        class CartController < ::Spree::Api::V2::BaseController
          include Spree::Api::V2::Storefront::OrderConcern
          before_action :ensure_order, except: :create

          def create
            spree_authorize! :create, Spree::Order

            order_params = {
              user: spree_current_user,
              store: spree_current_store,
              currency: current_currency
            }

            order   = spree_current_order if spree_current_order.present?
            order ||= create_service.call(order_params).value

            render_serialized_payload(201) { serialize_order(order) }
          end

          def add_item
            variant = Spree::Variant.find(params[:variant_id])

            spree_authorize! :update, spree_current_order, order_token
            spree_authorize! :show, variant

            result = add_item_service.call(
              order: spree_current_order,
              variant: variant,
              quantity: params[:quantity],
              options: params[:options]
            )

            render_order(result)
          end

          def remove_line_item
            spree_authorize! :update, spree_current_order, order_token

            remove_line_item_service.call(
              order: spree_current_order,
              line_item: line_item
            )

            render_serialized_payload { serialized_current_order }
          end

          def empty
            spree_authorize! :update, spree_current_order, order_token

            # TODO: we should extract this logic into service and let
            # developers overwrite it
            spree_current_order.empty!

            render_serialized_payload { serialized_current_order }
          end

          def set_quantity
            return render_error_item_quantity unless params[:quantity].to_i > 0

            spree_authorize! :update, spree_current_order, order_token

            result = set_item_quantity_service.call(order: spree_current_order, line_item: line_item, quantity: params[:quantity])

            render_order(result)
          end

          def show
            spree_authorize! :show, spree_current_order, order_token

            render_serialized_payload { serialized_current_order }
          end

          def apply_coupon_code
            spree_authorize! :update, spree_current_order, order_token

            spree_current_order.coupon_code = params[:coupon_code]
            result = coupon_handler.new(spree_current_order).apply

            if result.error.blank?
              render_serialized_payload { serialized_current_order }
            else
              render_error_payload(result.error)
            end
          end

          def remove_coupon_code
            spree_authorize! :update, spree_current_order, order_token

            coupon_codes = select_coupon_codes

            return render_error_payload(Spree.t('v2.cart.no_coupon_code', scope: 'api')) if coupon_codes.empty?

            result_errors = coupon_codes.count > 1 ? select_errors(coupon_codes) : select_error(coupon_codes)

            if result_errors.blank?
              render_serialized_payload { serialized_current_order }
            else
              render_error_payload(result_errors)
            end
          end

          def estimate_shipping_rates
            spree_authorize! :show, spree_current_order, order_token

            result = estimate_shipping_rates_service.call(order: spree_current_order, country_iso: params[:country_iso])

            if result.error.blank?
              render_serialized_payload { serialize_estimated_shipping_rates(result.value) }
            else
              render_error_payload(result.error)
            end
          end

          private

          def resource_serializer
            Spree::Api::Dependencies.storefront_cart_serializer.constantize
          end

          def create_service
            Spree::Api::Dependencies.storefront_cart_create_service.constantize
          end

          def add_item_service
            Spree::Api::Dependencies.storefront_cart_add_item_service.constantize
          end

          def set_item_quantity_service
            Spree::Api::Dependencies.storefront_cart_set_item_quantity_service.constantize
          end

          def remove_line_item_service
            Spree::Api::Dependencies.storefront_cart_remove_line_item_service.constantize
          end

          def coupon_handler
            Spree::Api::Dependencies.storefront_coupon_handler.constantize
          end

          def estimate_shipping_rates_service
            Spree::Api::Dependencies.storefront_cart_estimate_shipping_rates_service.constantize
          end

          def line_item
            @line_item ||= spree_current_order.line_items.find(params[:line_item_id])
          end

          def render_error_item_quantity
            render json: { error: I18n.t(:wrong_quantity, scope: 'spree.api.v2.cart') }, status: 422
          end

          def estimate_shipping_rates_serializer
            Spree::Api::Dependencies.storefront_estimated_shipment_serializer.constantize
          end

          def serialize_estimated_shipping_rates(shipping_rates)
            estimate_shipping_rates_serializer.new(
              shipping_rates,
              params: { currency: spree_current_order.currency }
            ).serializable_hash
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
