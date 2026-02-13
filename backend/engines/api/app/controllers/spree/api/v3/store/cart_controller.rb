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

            render json: serialize_resource(@cart)
          end

          # PATCH /api/v3/store/cart/associate
          # Associates a guest cart with the currently authenticated user
          # Requires: JWT authentication + order token (header or param)
          def associate
            @cart = find_cart_by_token

            # Associate the cart with the current user
            @cart.associate_user!(current_user)

            render json: serialize_resource(@cart)
          end

          protected

          def serializer_class
            Spree.api.order_serializer
          end

          private

          # Find incomplete cart by order token for associate action
          # Only finds guest carts (no user) or carts already owned by current user (idempotent)
          def find_cart_by_token
            current_store.orders.incomplete.where(user: [nil, current_user]).find_by!(token: order_token)
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
