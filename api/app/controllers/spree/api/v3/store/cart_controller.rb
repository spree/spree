module Spree
  module Api
    module V3
      module Store
        class CartController < Store::BaseController
          include Spree::Api::V3::OrderConcern

          before_action :require_authentication!, only: [:associate]

          # GET /api/v3/store/cart
          # Returns current incomplete order (cart)
          # Returns 404 if no cart exists - use POST /orders to create one
          # Authorize via order_token param or JWT Bearer token
          def show
            @cart = find_cart

            if @cart.nil?
              render_error(
                code: ERROR_CODES[:record_not_found],
                message: 'No cart found. Create one with POST /orders',
                status: :not_found
              )
              return
            end

            render json: serialize_resource(@cart)
          end

          # PATCH /api/v3/store/cart/associate
          # Associates a guest cart with the currently authenticated user
          # Requires: JWT authentication + order token (header or param)
          def associate
            @cart = find_cart_by_token

            if @cart.nil?
              render_error(
                code: ERROR_CODES[:record_not_found],
                message: 'Cart not found. Provide a valid order token.',
                status: :not_found
              )
              return
            end

            if @cart.completed?
              render_error(
                code: ERROR_CODES[:order_already_completed],
                message: 'Cannot associate a completed order',
                status: :unprocessable_entity
              )
              return
            end

            # Check if cart already belongs to a different user
            if @cart.user.present? && @cart.user != current_user
              render_error(
                code: ERROR_CODES[:access_denied],
                message: 'This cart belongs to another user',
                status: :forbidden
              )
              return
            end

            # Associate the cart with the current user
            @cart.associate_user!(current_user)

            render json: serialize_resource(@cart)
          end

          protected

          def serializer_class
            Spree.api.order_serializer
          end

          private

          # Find cart by order token only (for associate action)
          def find_cart_by_token
            token = order_token
            return nil unless token.present?

            current_store.orders.find_by(token: token)
          end

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

          # Cart always includes line_items by default
          def include_list
            base = super
            base.include?('line_items') ? base : base + ['line_items']
          end
        end
      end
    end
  end
end
