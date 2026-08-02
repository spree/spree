module Spree
  module Api
    module V3
      module Store
        class OrdersController < Store::BaseController
          # GET /api/v3/store/orders/:id
          # Single order lookup — accessible via order token (guests) or JWT (authenticated users)
          before_action :find_order!

          def show
            render json: serializer_class.new(@order, params: serializer_params).to_h
          end

          private

          # The cart's prefixed id stays the client's stable checkout handle:
          # after completion it resolves here to the order created from that
          # cart (Order#cart_id is unique; the order copies the cart token).
          def find_order!
            cart_pk = Spree::Cart.decode_own_prefixed_id(params[:id])
            @order = cart_pk ? scope.find_by!(cart_id: cart_pk) : scope.find_by_prefix_id!(params[:id])
            authorize!(:show, @order, order_token)
          end

          def scope
            base = current_store.orders.complete

            if current_user.present?
              base.where(user: current_user)
            elsif order_token.present?
              base.where(token: order_token)
            else
              base.none
            end
          end

          def serializer_class
            Spree.api.order_serializer
          end
        end
      end
    end
  end
end
