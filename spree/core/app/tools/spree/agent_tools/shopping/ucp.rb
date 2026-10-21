module Spree
  module AgentTools
    module Shopping
      # Store API records reshaped into Universal Commerce Protocol objects.
      #
      # Only reshaping: every value comes from a Store API response, so what a
      # shopper's agent sees is exactly what the storefront would show — the
      # same prices, the same gating, nothing a Store serializer withholds.
      #
      # UCP amounts are integers in the currency's minor units; the Store API's
      # are canonical decimal strings, converted here and nowhere else.
      #
      # See https://ucp.dev/2026-08-25/specification/overview/
      module Ucp
        VERSION = '2026-08-25'.freeze
        SPEC = "https://ucp.dev/#{VERSION}".freeze

        CAPABILITIES = {
          catalog_search: 'dev.ucp.shopping.catalog.search',
          catalog_lookup: 'dev.ucp.shopping.catalog.lookup',
          cart: 'dev.ucp.shopping.cart',
          checkout: 'dev.ucp.shopping.checkout',
          order: 'dev.ucp.shopping.order'
        }.freeze

        # Where each capability is specified, and the schema its objects follow.
        CAPABILITY_DOCUMENTS = {
          catalog_search: %w[shopping/catalog/search shopping/catalog_search.json],
          catalog_lookup: %w[shopping/catalog/lookup shopping/catalog_lookup.json],
          cart: %w[shopping/cart shopping/cart.json],
          checkout: %w[shopping/checkout shopping/checkout.json],
          order: %w[shopping/order shopping/order.json]
        }.freeze

        class << self
          # The `ucp` block every response carries. It names only the
          # capabilities the operation belongs to, as the spec asks.
          #
          # @param capabilities [Array<Symbol>]
          # @param status [String] `success` or `error`
          # @return [Hash]
          def envelope(*capabilities, status: 'success')
            envelope = {
              version: VERSION,
              status: status,
              capabilities: capabilities.to_h { |key| [CAPABILITIES.fetch(key), [{ version: VERSION }]] }
            }
            # A checkout response must say how it can be paid. Nothing is paid
            # through this server, so the answer is an empty map.
            envelope[:payment_handlers] = {} if capabilities.include?(:checkout)
            envelope
          end

          # A refusal the agent reads and acts on. UCP returns these as a
          # normal result, not a protocol error, so the agent sees the message.
          #
          # @param code [String] e.g. `not_found`
          # @param content [String] what happened, and what to do about it
          # @param severity [String] `recoverable`, `requires_buyer_input`,
          #   `requires_buyer_review` or `unrecoverable`
          # @return [Hash]
          def error(code, content, *capabilities, severity: 'unrecoverable', path: nil)
            {
              ucp: envelope(*capabilities, status: 'error'),
              messages: [{ type: 'error', code: code, content: content, severity: severity, path: path }.compact]
            }
          end

          # The store's business profile, served for `/.well-known/ucp`.
          #
          # @param endpoint [String] the MCP endpoint's absolute URL
          # @return [Hash]
          def profile(endpoint:)
            {
              ucp: {
                version: VERSION,
                services: {
                  'dev.ucp.shopping' => [{
                    version: VERSION,
                    spec: "#{SPEC}/specification/overview/",
                    transport: 'mcp',
                    endpoint: endpoint,
                    schema: "#{SPEC}/services/shopping/mcp.openrpc.json"
                  }]
                },
                capabilities: CAPABILITY_DOCUMENTS.to_h do |key, (spec, schema)|
                  [CAPABILITIES.fetch(key), [{ version: VERSION, spec: "#{SPEC}/specification/#{spec}", schema: "#{SPEC}/schemas/#{schema}" }]]
                end,
                payment_handlers: {}
              }
            }
          end

          # @param json [Hash] a Store API product, with variants expanded
          # @return [Hash]
          def product(json)
            variants = purchasable_variants(json).map { |variant| variant(variant, json) }
            prices = variants.filter_map { |variant| variant[:price] }

            {
              id: json['id'],
              handle: json['slug'],
              title: json['name'],
              description: description(json['description'], json['description_html']),
              price_range: prices.any? ? { min: prices.min_by { |price| price[:amount] }, max: prices.max_by { |price| price[:amount] } } : nil,
              media: image(json['thumbnail_url']),
              categories: Array(json['categories']).map { |category| { value: category['name'] } }.presence,
              tags: Array(json['tags']).presence,
              options: Array(json['option_types']).map do |option_type|
                values = Array(json['option_values']).select { |value| value['option_type_id'] == option_type['id'] }
                { name: option_type['label'] || option_type['name'], values: values.map { |value| { id: value['id'], label: value['label'] } } }
              end.presence,
              variants: variants
            }.compact
          end

          # What a cart can hold. A product without option variants is bought
          # as its default variant, so that one stands in rather than leaving
          # the agent a product it cannot put in a cart.
          #
          # @param json [Hash]
          # @return [Array<Hash>]
          def purchasable_variants(json)
            Array(json['variants']).presence || [json['default_variant']].compact
          end

          # @param json [Hash] a Store API variant
          # @param product [Hash] the product it belongs to
          # @return [Hash]
          def variant(json, product)
            options_text = json['options_text'].presence

            {
              id: json['id'],
              sku: json['sku'].presence,
              title: [product['name'], options_text].compact.join(' — '),
              description: { plain: options_text || product['name'] },
              price: price(json['price']),
              list_price: price(json['original_price']),
              availability: { available: json['purchasable'] == true, status: availability_status(json) },
              options: Array(json['option_values']).map do |value|
                { name: value['option_type_label'] || value['option_type_name'], label: value['label'], id: value['id'] }.compact
              end.presence,
              media: image(json['thumbnail_url'])
            }.compact
          end

          # @param json [Hash] a Store API cart
          # @param id [String] the cart's token, which is its UCP id
          # @param continue_url [String]
          # @return [Hash]
          def cart(json, id:, continue_url:)
            {
              ucp: envelope(:cart),
              id: id,
              line_items: line_items(json),
              currency: json['currency'],
              totals: totals(json),
              messages: warnings(json).presence,
              continue_url: continue_url
            }.compact
          end

          # A Spree cart is also its checkout. Until payment can happen in the
          # agent, every checkout with something in it hands the buyer to the
          # store's own checkout page.
          #
          # @param json [Hash] a Store API cart, or the purchase it became — an
          #   order, or the group a multi-seller checkout was divided into
          # @param id [String] the cart's token, which is its UCP id
          # @param continue_url [String, nil] where to send the buyer; nil once
          #   completed, or when the store has no web checkout to send them to
          # @param permalink_url [String, nil] set once completed: the order's page
          # @return [Hash]
          def checkout(json, id:, continue_url:, permalink_url: nil)
            completed = json['completed_at'].present?
            status, message = checkout_status(json, completed, continue_url)

            {
              ucp: envelope(:checkout),
              id: id,
              status: status,
              buyer: buyer(json),
              line_items: line_items(json),
              currency: json['currency'],
              totals: totals(json),
              links: [],
              messages: [message, *warnings(json)].compact.presence,
              continue_url: (continue_url unless completed),
              order: (purchase_reference(json, id, permalink_url) if completed)
            }.compact
          end

          # What a buyer has been sent so far. Progress is counted from the
          # purchase's own fulfillments, across every seller's order when the
          # checkout was divided — never assumed.
          #
          # @param json [Hash] a Store API order, or an order group
          # @param id [String] the token the order and its checkout share
          # @param permalink_url [String, nil]
          # @return [Hash]
          def order(json, id:, permalink_url: nil)
            currency = json['currency']
            canceled = json['fulfillment_status'] == 'canceled'
            sent = sent_quantities(json)

            {
              ucp: envelope(:order),
              id: id,
              label: json['number'],
              checkout_id: id,
              permalink_url: permalink_url,
              line_items: purchase_items(json).map do |item|
                total = canceled ? 0 : item['quantity'].to_i
                fulfilled = [sent[item['id']].to_i, total].min

                {
                  id: item['id'],
                  item: line_item_item(item, currency),
                  quantity: { original: item['quantity'].to_i, total: total, fulfilled: fulfilled },
                  totals: [{ type: 'total', amount: minor(item['total'], currency) }],
                  status: line_status(total, fulfilled)
                }
              end,
              fulfillment: { expectations: expectations(json), events: events(json) },
              currency: currency,
              totals: totals(json)
            }.compact
          end

          # @param amount [String, nil] a canonical decimal string
          # @param currency [String]
          # @return [Integer, nil]
          def minor(amount, currency)
            return if amount.blank? || currency.blank?

            Spree::Money::Rounding.to_minor_units(amount, currency)
          end

          private

          def price(json)
            return if json.blank? || json['amount'].blank?

            { amount: minor(json['amount'], json['currency']), currency: json['currency'] }
          end

          def description(plain, html)
            { plain: plain.to_s, html: html.presence }.compact
          end

          def image(url)
            [{ type: 'image', url: url }] if url.present?
          end

          def availability_status(json)
            if json['in_stock'] then 'in_stock'
            elsif json['preorder'] then 'preorder'
            elsif json['backorderable'] then 'backorder'
            else 'out_of_stock'
            end
          end

          def line_items(json)
            currency = json['currency']

            purchase_items(json).map do |item|
              {
                id: item['id'],
                item: line_item_item(item, currency),
                quantity: item['quantity'],
                totals: [
                  { type: 'subtotal', amount: minor(item['price'], currency).to_i * item['quantity'].to_i },
                  { type: 'total', amount: minor(item['total'], currency) }
                ]
              }
            end
          end

          def line_item_item(item, currency)
            {
              id: item['variant_id'],
              title: [item['name'], item['options_text'].presence].compact.join(' — '),
              price: minor(item['price'], currency),
              image_url: item['thumbnail_url'].presence
            }.compact
          end

          # Exactly one subtotal and one total, as the spec requires; the rest
          # only when they apply. Discounts arrive negative already.
          def totals(json)
            currency = json['currency']
            rows = [
              ['subtotal', json['item_total']],
              ['discount', json['discount_total']],
              ['fulfillment', json['delivery_total']],
              ['tax', json['additional_tax_total']],
              ['fee', json['fee_total']],
              ['total', json['total']]
            ]

            rows.filter_map do |type, amount|
              value = minor(amount, currency)
              next if value.nil?
              next if value.zero? && !%w[subtotal total].include?(type)

              { type: type, amount: value }
            end
          end

          def buyer(json)
            address = json['shipping_address'] || json['billing_address'] || {}

            {
              email: json['email'].presence,
              first_name: address['first_name'].presence,
              last_name: address['last_name'].presence,
              phone_number: address['phone'].presence
            }.compact.presence
          end

          def warnings(json)
            Array(json['warnings']).map do |warning|
              { type: 'warning', code: warning['code'], content: warning['message'] }
            end
          end

          def checkout_status(json, completed, continue_url)
            return ['completed', nil] if completed
            if purchase_items(json).empty?
              return ['incomplete', { type: 'error', code: 'empty_cart', severity: 'recoverable',
                                      content: 'The checkout has no items. Add line_items with update_checkout.' }]
            end
            # Escalating promises a page to send the buyer to. A store with no
            # web storefront has none, so the checkout says it cannot be
            # finished here rather than handing out a link that goes nowhere.
            if continue_url.nil?
              return ['incomplete', { type: 'error', code: 'checkout_unavailable', severity: 'unrecoverable',
                                      content: 'This store does not take payment through agents and has no web ' \
                                               'checkout to send the buyer to. The buyer can finish in the store\'s own app.' }]
            end

            ['requires_escalation', {
              type: 'error', code: 'buyer_handoff', severity: 'requires_buyer_input',
              content: 'Payment and delivery are completed on the store\'s own checkout. ' \
                       'Give the buyer continue_url to finish; the cart is kept as it is.'
            }]
          end

          def purchase_reference(json, id, permalink_url)
            { id: id, label: json['number'], permalink_url: permalink_url }.compact
          end

          # A multi-seller checkout became a group of orders; its items and
          # parcels are the union of theirs.
          def purchase_items(json)
            json['orders'] ? json['orders'].flat_map { |order| Array(order['items']) } : Array(json['items'])
          end

          def purchase_fulfillments(json)
            json['orders'] ? json['orders'].flat_map { |order| Array(order['fulfillments']) } : Array(json['fulfillments'])
          end

          SENT = %w[fulfilled delivered].freeze

          # @return [Hash{String => Integer}] quantity sent, by line item id
          def sent_quantities(json)
            purchase_fulfillments(json).select { |fulfillment| SENT.include?(fulfillment['status']) }.
              flat_map { |fulfillment| Array(fulfillment['items']) }.
              each_with_object(Hash.new(0)) { |item, sent| sent[item['item_id']] += item['quantity'].to_i }
          end

          # Derived exactly as the spec defines it.
          def line_status(total, fulfilled)
            if total.zero? then 'removed'
            elsif fulfilled == total then 'fulfilled'
            elsif fulfilled.positive? then 'partial'
            else 'processing'
            end
          end

          # Parcels not yet sent, and where they are going.
          def expectations(json)
            destination = postal_address(json['shipping_address'])

            purchase_fulfillments(json).filter_map do |fulfillment|
              next unless fulfillment['status'] == 'unfulfilled' && destination

              {
                id: fulfillment['id'],
                line_items: fulfillment_lines(fulfillment),
                method_type: fulfillment['fulfillment_type'].to_s.start_with?('pickup') ? 'pickup' : fulfillment['fulfillment_type'],
                destination: destination
              }.compact
            end
          end

          # A parcel that left, and one that arrived. Spree records when each
          # happened, not every scan in between.
          def events(json)
            purchase_fulfillments(json).flat_map do |fulfillment|
              base = { id: fulfillment['id'], line_items: fulfillment_lines(fulfillment),
                       tracking_number: fulfillment['tracking'].presence,
                       tracking_url: fulfillment['tracking_url'].presence }.compact

              [
                (base.merge(type: 'shipped', occurred_at: fulfillment['fulfilled_at']) if fulfillment['fulfilled_at']),
                (base.merge(id: "#{fulfillment['id']}-delivered", type: 'delivered', occurred_at: fulfillment['delivered_at']) if fulfillment['delivered_at'])
              ].compact
            end
          end

          def fulfillment_lines(fulfillment)
            Array(fulfillment['items']).map { |item| { id: item['item_id'], quantity: item['quantity'].to_i } }
          end

          def postal_address(address)
            return if address.blank?

            {
              first_name: address['first_name'].presence,
              last_name: address['last_name'].presence,
              street_address: address['address1'].presence,
              extended_address: address['address2'].presence,
              address_locality: address['city'].presence,
              address_region: (address['state_code'].presence || address['state_text'].presence),
              postal_code: address['postal_code'].presence,
              address_country: address['country_code'].presence,
              phone_number: address['phone'].presence
            }.compact
          end
        end
      end
    end
  end
end
