module Spree
  module Api
    module V3
      module Store
        class CartsController < Store::BaseController
          include Spree::Api::V3::CartResolvable
          include Spree::Api::V3::OrderLock

          prepend_before_action :require_authentication!, only: [:index, :associate]

          # GET /api/v3/store/carts
          # Lists all active (incomplete) carts for the authenticated user
          def index
            carts = current_user.carts.where(store: current_store).order(updated_at: :desc)
            render json: {
              data: carts.map { |c| Spree.api.cart_serializer.new(c, params: serializer_params).to_h },
              meta: { count: carts.size }
            }
          end

          # GET /api/v3/store/carts/:id
          # Returns cart by prefixed ID
          # Auto-advances the checkout state machine so that shipments and
          # payment requirements are up-to-date (temporary until Spree 6 removes
          # the state machine).
          def show
            @cart = find_cart

            if @cart.ship_address_id.present? && @cart.shipments.empty?
              with_order_lock { Spree::Checkout::Advance.call(order: @cart) }
            end

            render_cart
          end

          # POST /api/v3/store/carts
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

          # PATCH /api/v3/store/carts/:id
          # Updates cart info (email, addresses, special instructions).
          # Auto-advances to the next checkout step when possible.
          def update
            find_cart!

            with_order_lock do
              result = Spree::Carts::Update.new.call(
                cart: @cart,
                params: update_params
              )

              if result.success?
                render_cart
              else
                render_service_error(result.error, code: ERROR_CODES[:validation_error])
              end
            end
          end

          # DELETE /api/v3/store/carts/:id
          # Deletes/abandons the cart
          def destroy
            find_cart!

            result = Spree.cart_destroy_service.call(order: @cart)

            if result.success?
              head :no_content
            else
              render_service_error(result.error.to_s)
            end
          end

          # PATCH /api/v3/store/carts/:id/associate
          # Associates a guest cart with the currently authenticated user
          # Requires: JWT authentication + cart ID in URL
          def associate
            @cart = find_cart_for_association

            result = Spree.cart_associate_service.call(guest_order: @cart, user: current_user, guest_only: true)

            if result.success?
              render_cart
            else
              render_service_error(result.error.to_s)
            end
          end

          # POST /api/v3/store/carts/:id/complete
          # Completes the checkout — returns Order (not Cart)
          def complete
            find_cart!

            with_order_lock do
              result = Spree.checkout_complete_service.call(order: @cart)

              if result.success?
                render_order
              else
                render_service_error(result.error, code: ERROR_CODES[:order_already_completed])
              end
            end
          end

          private

          def cart_params
            params.permit(
              metadata: {},
              line_items: [:variant_id, :quantity, { metadata: {}, options: {} }]
            )
          end

          def update_params
            params.permit(
              :email,
              :special_instructions,
              :currency,
              :locale,
              :ship_address_id,
              :bill_address_id,
              ship_address: address_params,
              bill_address: address_params,
              metadata: {}
            )
          end

          def address_params
            [
              :id, :firstname, :lastname, :address1, :address2,
              :city, :zipcode, :phone, :company,
              :country_iso, :state_abbr, :state_name, :quick_checkout
            ]
          end

          # Find incomplete cart for associate action.
          # Only finds guest carts (no user) or carts already owned by current user (idempotent).
          def find_cart_for_association
            current_store.carts.where(user: [nil, current_user]).find_by_prefix_id!(params[:id])
          end
        end
      end
    end
  end
end
