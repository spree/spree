module Spree
  module Api
    module V3
      module CartResolvable
        extend ActiveSupport::Concern

        protected

        # Find cart by prefixed ID from URL params.
        # Falls back to token/JWT resolution for backward compatibility.
        # @return [Spree::Order]
        def find_cart
          cart_id = params[:cart_id] || params[:id]

          if cart_id.present?
            cart = current_store.carts.find_by_prefix_id!(cart_id)
            authorize_cart_access!(cart)
            return cart
          end

          # Legacy: resolve by token or JWT (used by checkout controllers during transition)
          if cart_token.present?
            return current_store.carts.find_by!(token: cart_token)
          end

          if current_user.present?
            cart = current_store.carts.where(user: current_user).order(created_at: :desc).first
            return cart if cart
          end

          raise ActiveRecord::RecordNotFound.new(nil, 'Spree::Order')
        end

        # Find the cart and authorize it for update.
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

        private

        # Verify the requesting user has access to this cart.
        # Access is granted if:
        #   - The request includes the cart's token (guest checkout)
        #   - The cart belongs to the authenticated user
        #   - The cart has no user (guest cart) and no token was provided
        def authorize_cart_access!(cart)
          return if cart_token.present? && cart.token == cart_token
          return if current_user.present? && cart.user_id == current_user.id
          return if cart.user_id.nil? && cart_token.blank?

          raise ActiveRecord::RecordNotFound.new(nil, 'Spree::Order')
        end
      end
    end
  end
end
