module Spree
  module Api
    module V3
      module Store
        class CartController < Store::BaseController
          include Spree::Api::V3::CartResolvable
          include Spree::Api::V3::OrderLock

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
              metadata: cart_params[:metadata] || {},
              line_items: cart_params[:line_items] || []
            )

            if result.success?
              @cart = result.value
              render_cart(status: :created)
            else
              render_service_error(result.error.to_s)
            end
          end

          # GET /api/v3/store/cart
          # Returns current incomplete order (cart)
          # Returns 404 if no cart exists - use POST /cart to create one
          # Authorize via cart_token param or JWT Bearer token
          # Uses find_cart (without bang) intentionally — read-only access, no authorize! needed
          #
          # Auto-advances the checkout state machine so that shipments and
          # payment requirements are up-to-date (temporary until Spree 6 removes
          # the state machine).
          def show
            @cart = find_cart

            if @cart && @cart.ship_address_id.present? && @cart.shipments.empty?
              with_order_lock { Spree::Checkout::Advance.call(order: @cart) }
            end

            render_cart
          end

          # DELETE /api/v3/store/cart
          # Deletes/abandons the current cart
          def destroy
            find_cart!

            result = Spree.cart_destroy_service.call(order: @cart)

            if result.success?
              head :no_content
            else
              render_service_error(result.error.to_s)
            end
          end

          # PATCH /api/v3/store/cart/associate
          # Associates a guest cart with the currently authenticated user
          # Requires: JWT authentication + order token (header or param)
          def associate
            @cart = find_cart_by_token

            result = Spree.cart_associate_service.call(guest_order: @cart, user: current_user, guest_only: true)

            if result.success?
              render_cart
            else
              render_service_error(result.error.to_s)
            end
          end

          private

          def cart_params
            params.permit(
              metadata: {},
              line_items: [:variant_id, :quantity, { metadata: {}, options: {} }]
            )
          end

          # Find incomplete cart by order token for associate action
          # Only finds guest carts (no user) or carts already owned by current user (idempotent)
          def find_cart_by_token
            current_store.carts.where(user: [nil, current_user]).find_by!(token: cart_token)
          end
        end
      end
    end
  end
end
