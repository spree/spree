module Spree
  module Api
    module V3
      module CartResolvable
        extend ActiveSupport::Concern

        include Spree::Api::V3::PurchaseSerialization

        protected

        # Find cart by prefixed ID and authorize read access (owner or guest
        # token). Completed carts are not carts anymore — they 404 unless the
        # caller opts in (idempotent completion, payment-session confirm races).
        #
        # Pass +token: nil+ to demand ownership. A guest token proves the
        # caller holds this cart, which is the right bar for the cart's own
        # contents and no higher — an endpoint reaching past the cart into
        # something the account holds asks for the account instead.
        #
        # @return [Spree::Cart]
        def find_cart(include_completed: false, token: cart_token)
          @cart = resolve_cart(include_completed: include_completed)
          authorize_storefront_read!(@cart, token: token)
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

        # Render the cart as JSON using the cart serializer. Rendering never
        # mutates: an action that wants unbuyable lines swept calls
        # +sweep_unbuyable_lines!+ itself first.
        def render_cart(status: :ok)
          preload_for_render(@cart)

          render json: Spree.api.cart_serializer.new(@cart, params: serializer_params).to_h, status: status
        end

        # A record that was just written holds line items and fulfillments
        # built one at a time, so they carry no preload context and every
        # association the serializer reads off them — variants, prices,
        # stock, delivery rates — would query once per row. Registering each
        # set as one context keeps rendering flat however the record was
        # built; a record read through a relation already has one.
        def preload_for_render(record)
          return unless record.respond_to?(:line_items)

          line_items = record.line_items.to_a
          fulfillments = record.respond_to?(:fulfillments) ? record.fulfillments.to_a : []
          ArLazyPreload::Context.register(records: line_items, auto_preload: true) if line_items.any?
          ArLazyPreload::Context.register(records: fulfillments, auto_preload: true) if fulfillments.any?

          # A variant the workflow assigned is already loaded and so sits
          # outside the line items' context; it needs one of its own.
          ActiveRecord::Associations::Preloader.new(records: line_items, associations: :variant).call
          variants = line_items.filter_map(&:variant).uniq(&:object_id)
          ArLazyPreload::Context.register(records: variants, auto_preload: true) if variants.any?
        end

        # Drops lines the customer can no longer buy — a discontinued product,
        # or stock that ran out while the cart sat idle. For reads of a cart
        # the customer is returning to, never for the write that just
        # happened: an add a stock check already approved must not be
        # second-guessed in the same request, and an external inventory
        # provider makes that contradiction routine, since the provider
        # answers the write while the sweep reads Spree's own rows.
        def sweep_unbuyable_lines!
          @cart = @cart.remove_out_of_stock_items!
        end

        # Drops a batch coupon code the cart no longer holds. Unlike the line
        # sweep this runs after writes too, since an API client may rely on
        # write responses alone to learn why its discount went.
        def sweep_unavailable_coupon_code!
          @cart = @cart.remove_unavailable_coupon_code!
        end

        # Render what the checkout produced (for the complete action).
        #
        # A checkout spanning several sellers produced a group of orders rather
        # than one order, and the group is what the customer bought — so it is
        # what comes back, with the per-seller orders nested inside it. A
        # storefront that knows nothing about groups still finds every order it
        # needs there.
        def render_order(status: :ok)
          # Read back through a lazily preloading relation rather than
          # reloaded in place: a group's orders, and everything each of them
          # renders, then load once for all of them instead of once per order.
          record = @cart.class.preload_associations_lazily.find(@cart.id)

          preload_for_render(record)

          render json: purchase_serializer_for(record).new(record, params: serializer_params).to_h, status: status
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
