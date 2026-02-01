module Spree
  module Api
    module V3
      module Store
        class CartController < Store::BaseController
          # GET /api/v3/store/cart
          # Returns current incomplete order (cart)
          # Returns 404 if no cart exists - use POST /orders to create one
          # Authorize via order_token param or JWT Bearer token
          def show
            @cart = find_cart

            if @cart.nil?
              render_error(
                code: ERROR_CODES[:not_found],
                message: 'No cart found. Create one with POST /orders',
                status: :not_found
              )
              return
            end

            render json: serialize_resource(@cart)
          end

          protected

          def serializer_class
            Spree.api.order_serializer
          end

          private

          def find_cart
            # Try order_token first (guest checkout)
            if params[:order_token].present?
              return current_store.orders
                .incomplete
                .find_by(token: params[:order_token])
            end

            # Then try JWT authenticated user
            if current_user.present?
              return current_store.orders
                .incomplete
                .where(user: current_user)
                .order(created_at: :desc)
                .first
            end

            nil
          end

          def serialize_resource(resource)
            result = serializer_class.new(resource, params: serializer_params).to_h
            # Always include order token for cart (needed for guest checkout)
            result[:token] = resource.token if resource.token.present?
            result
          end
        end
      end
    end
  end
end
