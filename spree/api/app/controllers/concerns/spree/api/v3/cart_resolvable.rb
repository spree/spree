module Spree
  module Api
    module V3
      module CartResolvable
        extend ActiveSupport::Concern

        protected

        def find_cart
          scope = current_store.carts

          # Try order_token first (guest checkout)
          if cart_token.present?
            return scope.find_by!(token: cart_token)
          end

          # Then try JWT authenticated user
          if current_user.present?
            cart = scope.where(user: current_user).order(created_at: :desc).first
            return cart if cart
          end

          raise ActiveRecord::RecordNotFound.new(nil, 'Spree::Order')
        end

        # Find the cart and authorize it for update using the cart token from the request headers.
        # @return [Spree::Order]
        def find_cart!
          @cart = find_cart
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
