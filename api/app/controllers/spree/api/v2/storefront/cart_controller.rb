module Spree
  module Api
    module V2
      module Storefront
        class CartController < ::Spree::Api::V2::BaseController
          include OrderConcern
          include CouponCodesHelper
          include Spree::Api::V2::Storefront::MetadataControllerConcern

          before_action :ensure_valid_metadata, only: %i[create add_item]
          before_action :ensure_order, except: %i[create associate]
          before_action :load_variant, only: :add_item
          before_action :require_spree_current_user, only: :associate

          def create
            spree_authorize! :create, Spree::Order

            create_cart_params = {
              user: spree_current_user,
              store: current_store,
              currency: current_currency,
              public_metadata: add_item_params[:public_metadata],
              private_metadata: add_item_params[:private_metadata],
            }

            order   = spree_current_order if spree_current_order.present?
            order ||= create_service.call(create_cart_params).value

            render_serialized_payload(201) { serialize_resource(order) }
          end

          def add_item
            spree_authorize! :update, spree_current_order, order_token
            spree_authorize! :show, @variant

            result = add_item_service.call(
              order: spree_current_order,
              variant: @variant,
              quantity: add_item_params[:quantity],
              public_metadata: add_item_params[:public_metadata],
              private_metadata: add_item_params[:private_metadata],
              options: add_item_params[:options]
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

            result = empty_cart_service.call(order: spree_current_order)

            if result.success?
              render_serialized_payload { serialized_current_order }
            else
              render_error_payload(result.error)
            end
          end

          def destroy
            spree_authorize! :update, spree_current_order, order_token

            result = destroy_cart_service.call(order: spree_current_order)

            if result.success?
              head 204
            else
              render_error_payload(result.error)
            end
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
              spree_current_order.reload
              render_serialized_payload { serialized_current_order }
            else
              render_error_payload(result.error)
            end
          end

          def remove_coupon_code
            spree_authorize! :update, spree_current_order, order_token

            coupon_codes = select_coupon_codes

            return render_error_payload(I18n.t('spree.api.v2.cart.no_coupon_code')) if coupon_codes.empty?

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

          def associate
            guest_order_token = params[:guest_order_token]
            guest_order = ::Spree::Api::Dependencies.storefront_current_order_finder.constantize.new.execute(
              store: current_store,
              user: nil,
              token: guest_order_token,
              currency: current_currency
            )

            spree_authorize! :update, guest_order, guest_order_token

            result = associate_service.call(guest_order: guest_order, user: spree_current_user)

            if result.success?
              render_serialized_payload { serialize_resource(guest_order) }
            else
              render_error_payload(result.error)
            end
          end

          def change_currency
            spree_authorize! :update, spree_current_order, order_token

            result = change_currency_service.call(order: spree_current_order, new_currency: params[:new_currency])

            render_order(result)
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

          def empty_cart_service
            Spree::Api::Dependencies.storefront_cart_empty_service.constantize
          end

          def destroy_cart_service
            Spree::Api::Dependencies.storefront_cart_destroy_service.constantize
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

          def associate_service
            Spree::Api::Dependencies.storefront_cart_associate_service.constantize
          end

          def change_currency_service
            Spree::Api::Dependencies.storefront_cart_change_currency_service.constantize
          end

          def line_item
            @line_item ||= spree_current_order.line_items.find(params[:line_item_id])
          end

          def load_variant
            @variant = current_store.variants.find(add_item_params[:variant_id])
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
              params: serializer_params
            ).serializable_hash
          end

          def add_item_params
            params.permit(:quantity, :variant_id, public_metadata: {}, private_metadata: {}, options: {})
          end
        end
      end
    end
  end
end
