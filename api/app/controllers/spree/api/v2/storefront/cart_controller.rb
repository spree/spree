module Spree
  module Api
    module V2
      module Storefront
        class CartController < ::Spree::Api::V2::BaseController
          def create
            spree_authorize! :create, Spree::Order

            order = spree_current_order || dependencies[:create_cart].call(user: spree_current_user, store: spree_current_store).value
            render json: serialize_order(order), status: 201
          end

          def add_item
            variant = Spree::Variant.find(params[:variant_id])

            if spree_current_order.nil?
              raise ActiveRecord::RecordNotFound
            else
              spree_authorize! :update, spree_current_order, order_token
              spree_authorize! :show, variant

              dependencies[:add_item_to_cart].call(order: spree_current_order, variant: variant, quantity: params[:quantity])
              render json: serialized_current_order, status: 200
            end
          end

          def remove_line_item
            raise ActiveRecord::RecordNotFound if spree_current_order.nil?

            spree_authorize! :update, spree_current_order, order_token

            dependencies[:remove_item_from_cart].call(
              order:     spree_current_order,
              line_item: line_item
            )
            render json: serialized_current_order, status: 200
          end

          def empty
            raise ActiveRecord::RecordNotFound if spree_current_order.nil?

            spree_authorize! :update, spree_current_order, order_token

            spree_current_order.empty!
            render json: serialized_current_order, status: 200
          end

          def set_quantity
            return render_error_item_quantity unless params[:quantity].to_i > 0

            line_item = spree_current_order.line_items.find(params[:line_item_id])

            spree_authorize! :update, spree_current_order, order_token

            result = dependencies[:set_item_quantity].call(order: spree_current_order, line_item: line_item, quantity: params[:quantity])

            if result.success?
              render json: serialized_current_order, status: 200
            else
              render json: { error: result.value }, status: 422
            end
          end

          def show
            raise ActiveRecord::RecordNotFound if spree_current_order.nil?

            spree_authorize! :show, spree_current_order, order_token
            render json: serialized_current_order, status: 200
          end

          private

          def dependencies
            {
              create_cart:           Spree::Cart::Create,
              add_item_to_cart:      Spree::Cart::AddItem,
              remove_item_from_cart: Spree::Cart::RemoveLineItem,
              cart_serializer:       Spree::V2::Storefront::CartSerializer,
              set_item_quantity:     Spree::Cart::SetQuantity
            }
          end

          def serialized_current_order
            serialize_order(spree_current_order)
          end

          def serialize_order(order)
            dependencies[:cart_serializer].new(order.reload, include: [:line_items, :variants, :promotions]).serializable_hash
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
