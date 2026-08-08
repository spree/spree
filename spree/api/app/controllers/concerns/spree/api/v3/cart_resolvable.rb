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
          authorize_purchase_read!(@cart, cart_token)
          @cart
        end

        # Find the cart and authorize it for mutation. A completed cart
        # resolves only for opted-in flows, where mutation is impossible — a
        # read check is the right bar there.
        # @return [Spree::Cart]
        def find_cart!(include_completed: false)
          @cart = resolve_cart(include_completed: include_completed)

          if @cart.completed?
            authorize_purchase_read!(@cart, cart_token)
          else
            authorize_purchase_write!(@cart, cart_token)
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
