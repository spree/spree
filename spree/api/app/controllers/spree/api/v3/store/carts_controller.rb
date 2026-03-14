module Spree
  module Api
    module V3
      module Store
        class CartsController < Store::ResourceController
          include Spree::Api::V3::CartResolvable
          include Spree::Api::V3::OrderLock

          skip_before_action :set_resource
          prepend_before_action :require_authentication!, only: [:index, :associate]

          # GET /api/v3/store/carts/:id
          # Returns cart by prefixed ID
          # Auto-advances the checkout state machine so that shipments and
          # payment requirements are up-to-date (temporary until Spree 6 removes
          # the state machine).
          def show
            @cart = find_cart

            if @cart.ship_address_id.present? && @cart.shipments.empty?
              ActiveRecord::Base.connected_to(role: :writing) do
                with_order_lock { Spree::Checkout::Advance.call(order: @cart) }
              end
            end

            render_cart
          end

          # POST /api/v3/store/carts
          # Creates a new shopping cart (order)
          # Can be created by guests or authenticated customers
          def create
            result = Spree::Carts::Create.call(
              params: permitted_params.merge(
                user: current_user,
                store: current_store,
                currency: current_currency,
                locale: current_locale
              )
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
              result = Spree::Carts::Update.call(
                cart: @cart,
                params: permitted_params
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
          # Completes the checkout — returns Order (not Cart).
          # Idempotent: if the cart is already completed, falls back to the
          # orders scope and returns the completed order.
          def complete
            find_cart!

            result = Spree::Dependencies.carts_complete_service.constantize.call(cart: @cart)

            if result.success?
              @cart = result.value
              render_order
            else
              render_service_error(
                result.error.to_s.presence || 'Could not complete checkout',
                code: ERROR_CODES[:cart_cannot_complete]
              )
            end
          rescue ActiveRecord::RecordNotFound
            @cart = current_store.orders.complete.find_by_prefix_id!(params[:id])
            authorize!(:show, @cart, cart_token)

            render_order
          end

          protected

          def model_class
            Spree::Order
          end

          def serializer_class
            Spree.api.cart_serializer
          end

          def scope
            current_store.carts.where(user: current_user).order(updated_at: :desc)
          end

          private

          def permitted_params
            params.permit(
              :email,
              :special_instructions,
              :currency,
              :locale,
              :ship_address_id,
              :bill_address_id,
              ship_address: address_params,
              bill_address: address_params,
              metadata: {},
              items: item_params
            )
          end

          def address_params
            [
              :id, :firstname, :lastname, :address1, :address2,
              :city, :zipcode, :phone, :company,
              :country_iso, :state_abbr, :state_name, :quick_checkout
            ]
          end

          def item_params
            [:variant_id, :quantity, { metadata: {}, options: {} }]
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
