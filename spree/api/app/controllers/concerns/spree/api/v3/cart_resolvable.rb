module Spree
  module Api
    module V3
      module CartResolvable
        extend ActiveSupport::Concern

        protected

        # Find cart by prefixed ID and authorize access via CanCanCan.
        # @return [Spree::Order]
        def find_cart
          cart_id = params[:cart_id] || params[:id]
          @cart = current_store.carts.find_by_prefix_id!(cart_id)
          authorize!(:show, @cart, cart_token)
          @cart
        end

        # Find the cart and authorize it for update.
        # @return [Spree::Order]
        def find_cart!
          cart_id = params[:cart_id] || params[:id]
          @cart = current_store.carts.find_by_prefix_id!(cart_id)
          authorize!(:update, @cart, cart_token)
          @cart
        end

        # Render the cart as JSON using the cart serializer.
        def render_cart(status: :ok)
          render json: Spree.api.cart_serializer.new(@cart.reload, params: serializer_params).to_h, status: status
        end

        # Render the order as JSON using the order serializer (for complete action).
        def render_order(status: :ok)
          render json: Spree.api.order_serializer.new(@cart.reload, params: serializer_params).to_h, status: status
        end

        # Return the cart token from the request headers.
        # @return [String, nil]
        def cart_token
          request.headers['x-spree-token']
        end
      end
    end
  end
end
