module Spree
  module AgentTools
    module Shopping
      # The base of every storefront tool: the UCP tools a shopper's agent
      # calls through `POST /api/v3/store/mcp`.
      #
      # Each one reaches the Store API with the caller's publishable key, so
      # storefront gating, hidden prices and channel scoping apply to an agent
      # exactly as they do to the storefront.
      #
      # A cart's UCP id is its token. The token is what authorizes a guest's
      # cart in the Store API, and it cannot be guessed — a prefixed cart id
      # encodes a sequential key, so handing one out would let an agent walk
      # every cart in the store.
      class Tool < Spree::AgentTool
        audience :store
        permission nil

        param :meta, type: :object,
                     description: 'UCP request metadata, e.g. {"ucp-agent": {"profile": "https://…"}}.'

        # What a product needs for an agent to choose and buy a variant of it.
        PRODUCT_EXPANSIONS = 'variants,default_variant,option_types,option_values,categories'.freeze

        # The UCP capability this tool answers for — a key of
        # {Ucp::CAPABILITIES}. A Spree cart is also its checkout, so the cart
        # and checkout tools differ only here.
        class_attribute :ucp_object, instance_writer: false, default: :cart

        protected

        def dispatch
          @dispatch ||= ApiDispatch.new(context)
        end

        # @param path [String] relative to the Store API root
        # @return [ApiDispatch::Response]
        def store_api(method, path, cart: nil, **options)
          headers = cart ? { 'HTTP_X_SPREE_TOKEN' => cart.token } : {}
          dispatch.call(method: method, path: "/api/v3/store/#{path}", headers: headers, **options)
        end

        # The cart a UCP id names, in this store only. Completed carts are
        # found too, so a checkout the buyer finished in the browser reads as
        # completed rather than vanishing.
        #
        # @param id [String, nil] the cart's token
        # @return [Spree::Cart, nil]
        def find_cart(id)
          return if id.blank?

          context.store.carts.find_by(token: id.to_s)
        end

        # The cart as the Store API sees it now, reshaped for the agent. A
        # completed cart is read as the order it became, which is the only
        # form the Store API still serves it in.
        #
        # @param cart [Spree::Cart]
        # @return [Hash]
        def present(cart)
          if cart.completed_at.present?
            response = purchase(cart)
            return failure(response) unless response.success?

            Ucp.checkout(response.data, id: cart.token, continue_url: nil, permalink_url: cart.storefront_order_url)
          else
            response = store_api(:get, "carts/#{cart.prefixed_id}", cart: cart)
            return failure(response) unless response.success?

            present_cart(cart, response.data)
          end
        end

        # What a completed cart became, read through the cart's own id: the
        # Store API answers it with the single order, or with the group a
        # checkout that reached several sellers was divided into — so the
        # agent always sees the whole purchase, never one seller's share.
        #
        # @param cart [Spree::Cart] a completed cart
        # @return [ApiDispatch::Response]
        def purchase(cart)
          store_api(:get, "orders/#{cart.prefixed_id}", cart: cart)
        end

        # @param cart [Spree::Cart]
        # @param json [Hash] the Store API cart
        # @return [Hash]
        def present_cart(cart, json)
          if ucp_object == :checkout
            Ucp.checkout(json, id: cart.token, continue_url: cart.storefront_checkout_url)
          else
            Ucp.cart(json, id: cart.token, continue_url: cart.storefront_checkout_url)
          end
        end

        # A new cart holding the payload's line items.
        #
        # @param payload [Hash] a UCP cart or checkout: `line_items`, `buyer`
        # @return [Hash]
        def create_from(payload)
          payload = object(payload)
          return invalid_argument(ucp_object) if payload.nil?

          items, refusal = cart_items(payload[:line_items])
          return refusal if refusal

          response = store_api(:post, 'carts', body: { items: items, **buyer_attributes(payload[:buyer]) })
          return failure(response) unless response.success?

          present_cart(context.store.carts.find_by!(token: response.data['token']), response.data)
        end

        # A UCP update replaces the whole cart, so the line items sent are
        # all it holds afterwards. A payload with no `line_items` at all
        # leaves the items alone rather than emptying the cart.
        #
        # @param cart [Spree::Cart, nil]
        # @param payload [Hash]
        # @return [Hash]
        def update_from(cart, payload)
          return not_found if cart.nil?
          return already_completed if cart.completed_at.present?

          payload = object(payload)
          return invalid_argument(ucp_object) if payload.nil?

          body = buyer_attributes(payload[:buyer])
          if payload.key?(:line_items)
            items, refusal = cart_items(payload[:line_items])
            return refusal if refusal

            body[:items] = replacement_items(cart, items)
          end

          response = store_api(:patch, "carts/#{cart.prefixed_id}", cart: cart, body: body)
          return failure(response) unless response.success?

          present_cart(cart, response.data)
        end

        # Answers with the cart as it was, which is what UCP returns for a
        # cancellation; the id is unknown from then on.
        #
        # @param cart [Spree::Cart, nil]
        # @return [Hash]
        def cancel(cart)
          return not_found if cart.nil?
          return already_completed if cart.completed_at.present?

          # Read first, and only delete what could be read: a cart the agent
          # is told it failed to cancel must still be there.
          before = present(cart)
          return before if before.dig(:ucp, :status) == 'error'

          response = store_api(:delete, "carts/#{cart.prefixed_id}", cart: cart)
          return failure(response) unless response.success?

          before
        end

        # A tool argument as a hash, or nil when the agent sent something else
        # — a string where the spec wants an object is a common slip, and it
        # should come back as a message naming the fix, not a server error.
        #
        # @param value [Object]
        # @return [ActiveSupport::HashWithIndifferentAccess, nil]
        def object(value)
          value = value.to_unsafe_h if value.respond_to?(:to_unsafe_h)
          value.with_indifferent_access if value.is_a?(Hash)
        end

        # @param name [Symbol, String] the argument, as the spec names it
        # @return [Hash]
        def invalid_argument(name, path: "$.#{name}")
          Ucp.error('invalid', "#{name} must be an object, as described in this tool's input schema.",
                    ucp_object, severity: 'recoverable', path: path)
        end

        # @return [Hash]
        def not_found
          Ucp.error('not_found', "No #{ucp_object} with this id. A checkout the buyer opened from its continue_url is theirs now " \
                    "and no longer reachable here; otherwise create a new one with create_#{ucp_object}.", ucp_object)
        end

        # A completed checkout is a record of what was bought; it cannot be
        # changed or cancelled through the cart any more.
        #
        # @return [Hash]
        def already_completed
          Ucp.error('not_allowed', "This #{ucp_object} is completed. Read the order with get_order.", ucp_object)
        end

        # The Store API's own refusal, in its own words. A missing record is
        # `not_found`; anything else the agent can correct and retry.
        #
        # @param response [ApiDispatch::Response]
        # @return [Hash]
        def failure(response)
          return not_found if response.status == 404

          Ucp.error(response.body.dig('error', 'code').presence || 'invalid', response.error_message.to_s,
                    ucp_object, severity: 'recoverable')
        rescue NoMethodError
          Ucp.error('invalid', response.error_message.to_s, ucp_object, severity: 'recoverable')
        end

        # UCP line items (`{item: {id}, quantity}`) as the Store API's cart
        # items. Only variants go in a cart: a product id is refused with the
        # fix, rather than silently picking one of its variants for the buyer.
        #
        # @param line_items [Array<Hash>, nil]
        # @return [Array(Array<Hash>, Hash)] the items, or nil and the refusal
        def cart_items(line_items)
          return [nil, invalid_argument(:line_items)] unless line_items.nil? || line_items.is_a?(Array)

          items = Array(line_items).each_with_index.map do |line_item, index|
            line_item = object(line_item)
            item = object(line_item&.dig(:item))
            if item.nil?
              return [nil, Ucp.error('invalid_item', 'Each line item is {"item": {"id": "<variant id>"}, "quantity": 1}.',
                                     ucp_object, severity: 'recoverable', path: "$.line_items[#{index}].item")]
            end

            id = item[:id].to_s
            quantity = Integer(line_item[:quantity].presence || 1, exception: false).to_i

            unless id.start_with?("#{Spree::Variant._prefix_id_prefix}_")
              return [nil, Ucp.error('invalid_item', "#{id.presence || 'A line item'} is not a variant id. " \
                                     'Put one of the product\'s variants (from get_product) in the cart.',
                                     ucp_object, severity: 'recoverable', path: "$.line_items[#{index}].item.id")]
            end
            if quantity < 1
              return [nil, Ucp.error('invalid_quantity', 'A quantity must be at least 1. Leave the line out to remove it.',
                                     ucp_object, severity: 'recoverable', path: "$.line_items[#{index}].quantity")]
            end

            { variant_id: id, quantity: quantity }
          end

          [items, nil]
        end

        # The item list that makes the cart hold exactly `items`: UCP updates
        # replace the whole cart, so a variant the agent left out is removed.
        #
        # @param cart [Spree::Cart]
        # @param items [Array<Hash>]
        # @return [Array<Hash>]
        def replacement_items(cart, items)
          kept = items.map { |item| item[:variant_id] }
          removed = cart.line_items.includes(:variant).map { |line_item| line_item.variant.prefixed_id } - kept

          items + removed.map { |variant_id| { variant_id: variant_id, quantity: 0 } }
        end

        # @param buyer [Hash, nil]
        # @return [Hash] the cart fields a UCP buyer carries
        def buyer_attributes(buyer)
          email = object(buyer)&.dig(:email)
          email.present? ? { email: email } : {}
        end
      end
    end
  end
end
