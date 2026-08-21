module Spree
  module Api
    module V3
      module CartResolvable
        extend ActiveSupport::Concern

        protected

        # Find cart by prefixed ID and authorize read access (owner or guest
        # token). Completed carts are not carts anymore — they 404 unless the
        # caller opts in (idempotent completion, payment-session confirm races).
        # @return [Spree::Cart]
        def find_cart(include_completed: false)
          @cart = resolve_cart(include_completed: include_completed)
          authorize_storefront_read!(@cart, token: cart_token)
          @cart
        end

        # Find the cart and authorize it for mutation. A completed cart
        # resolves only for opted-in flows, where mutation is impossible — a
        # read check is the right bar there.
        # @return [Spree::Cart]
        def find_cart!(include_completed: false)
          @cart = resolve_cart(include_completed: include_completed)

          if @cart.completed?
            authorize_storefront_read!(@cart, token: cart_token)
          else
            authorize_storefront_write!(@cart, token: cart_token)
          end

          @cart
        end

        def resolve_cart(include_completed:)
          cart_id = params[:cart_id] || params[:id]
          scope = current_store.carts
          scope = scope.incomplete unless include_completed
          scope.find_by_prefix_id!(cart_id)
        end

        # Render the cart as JSON using the cart serializer.
        def render_cart(status: :ok)
          @cart = @cart.remove_out_of_stock_items!
          render json: Spree.api.cart_serializer.new(@cart, params: serializer_params).to_h, status: status
        end

        # Render what the checkout produced (for the complete action).
        #
        # A checkout spanning several sellers produced a group of orders rather
        # than one order, and the group is what the customer bought — so it is
        # what comes back, with the per-seller orders nested inside it. A
        # storefront that knows nothing about groups still finds every order it
        # needs there.
        def render_order(status: :ok)
          record = @cart.reload
          serializer = record.is_a?(Spree::OrderGroup) ? Spree.api.order_group_serializer : Spree.api.order_serializer

          render json: serializer.new(record, params: serializer_params).to_h, status: status
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
