module Spree
  module Api
    module V3
      module Store
        class CartController < Store::BaseController
          include Spree::Api::V3::OrderConcern

          before_action :require_authentication!, only: [:associate]

          # POST /api/v3/store/cart
          # Creates a new shopping cart (order)
          # Can be created by guests or authenticated customers
          def create
            result = Spree.cart_create_service.call(
              user: current_user,
              store: current_store,
              currency: current_currency,
              locale: current_locale,
              metadata: cart_params[:metadata] || {}
            )

            if result.success?
              @cart = result.value
              render json: serialize_resource(@cart), status: :created
            else
              render_service_error(result.error.to_s)
            end
          end

          # GET /api/v3/store/cart
          # Returns current incomplete order (cart)
          # Returns 404 if no cart exists - use POST /cart to create one
          # Authorize via order_token param or JWT Bearer token
          def show
            @cart = find_cart

            render json: serialize_resource(@cart)
          end

          # PATCH /api/v3/store/cart/associate
          # Associates a guest cart with the currently authenticated user
          # Requires: JWT authentication + order token (header or param)
          def associate
            @cart = find_cart_by_token

            result = Spree.cart_associate_service.call(guest_order: @cart, user: current_user, guest_only: true)

            if result.success?
              render json: serialize_resource(@cart)
            else
              render_service_error(result.error.to_s)
            end
          end

          protected

          def serializer_class
            Spree.api.order_serializer
          end

          private

          def cart_params
            params.permit(metadata: {})
          end

          # Find incomplete cart by order token for associate action
          # Only finds guest carts (no user) or carts already owned by current user (idempotent)
          def find_cart_by_token
            current_store.orders.incomplete.where(user: [ nil, current_user ]).find_by!(token: order_token)
          end

          def find_cart
            scope = current_store.orders.incomplete

            # Try order_token first (guest checkout)
            if order_token.present?
              return scope.find_by!(token: order_token)
            end

            # Then try JWT authenticated user
            if current_user.present?
              cart = scope.where(user: current_user).order(created_at: :desc).first
              return cart if cart
            end

            raise ActiveRecord::RecordNotFound.new(nil, 'Spree::Order')
          end
        end
      end
    end
  end
end
