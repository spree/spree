module Spree
  module Api
    module V2
      module Storefront
        class CartController < ::Spree::Api::V2::BaseController
          before_action :ensure_order, except: :create

          def create
            spree_authorize! :create, Spree::Order

            order_params = {
              user: spree_current_user,
              store: spree_current_store,
              currency: current_currency
            }

            order   = spree_current_order if spree_current_order.present?
            order ||= dependencies[:create_cart].call(order_params).value

            render_serialized_payload serialize_order(order), 201
          end

          def add_item
            variant = Spree::Variant.find(params[:variant_id])

            spree_authorize! :update, spree_current_order, order_token
            spree_authorize! :show, variant

            result = dependencies[:add_item_to_cart].call(
              order: spree_current_order,
              variant: variant,
              quantity: params[:quantity],
              options: params[:options]
            )

            if result.success?
              render_serialized_payload serialized_current_order
            else
              render_error_payload(result.error)
            end
          end

          def remove_line_item
            spree_authorize! :update, spree_current_order, order_token

            dependencies[:remove_item_from_cart].call(
              order: spree_current_order,
              line_item: line_item
            )

            render_serialized_payload serialized_current_order
          end

          def empty
            spree_authorize! :update, spree_current_order, order_token

            spree_current_order.empty!

            render_serialized_payload serialized_current_order
          end

          def set_quantity
            return render_error_item_quantity unless params[:quantity].to_i > 0

            spree_authorize! :update, spree_current_order, order_token

            result = dependencies[:set_item_quantity].call(order: spree_current_order, line_item: line_item, quantity: params[:quantity])

            if result.success?
              render_serialized_payload serialized_current_order
            else
              render_error_payload(result.error)
            end
          end

          def show
            spree_authorize! :show, spree_current_order, order_token

            render_serialized_payload serialized_current_order
          end

          def apply_coupon_code
            spree_authorize! :update, spree_current_order, order_token

            spree_current_order.coupon_code = params[:coupon_code]
            result = dependencies[:coupon_handler].new(spree_current_order).apply

            if result.error.blank?
              render_serialized_payload serialized_current_order
            else
              render_error_payload(result.error)
            end
          end

          def remove_coupon_code
            spree_authorize! :update, spree_current_order, order_token

            result = dependencies[:coupon_handler].new(spree_current_order).remove(params[:coupon_code])

            if result.error.blank?
              render_serialized_payload serialized_current_order
            else
              render_error_payload(result.error)
            end
          end

          private

          def ensure_order
            raise ActiveRecord::RecordNotFound if spree_current_order.nil?
          end

          def dependencies
            {
              create_cart: Spree::Cart::Create,
              add_item_to_cart: Spree::Cart::AddItem,
              remove_item_from_cart: Spree::Cart::RemoveLineItem,
              cart_serializer: Spree::V2::Storefront::CartSerializer,
              set_item_quantity: Spree::Cart::SetQuantity,
              coupon_handler: Spree::PromotionHandler::Coupon
            }
          end

          def serialized_current_order
            serialize_order(spree_current_order)
          end

          def serialize_order(order)
            dependencies[:cart_serializer].new(order.reload, include: resource_includes).serializable_hash
          end

          def line_item
            @line_item ||= spree_current_order.line_items.find(params[:line_item_id])
          end

          def render_error_item_quantity
            render json: { error: I18n.t(:wrong_quantity, scope: 'spree.api.v2.cart') }, status: 422
          end
        end
      end
    end
  end
end
