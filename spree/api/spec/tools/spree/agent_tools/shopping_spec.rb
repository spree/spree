require 'spec_helper'

# The storefront's UCP tools, called the way the MCP adapter calls them and
# answering through the real Store API. Several examples are the failures
# other platforms shipped and then fixed in the field: a product id put in a
# cart, an empty search, an unknown cart id, a partial update, a stale price.
RSpec.describe 'Storefront agent tools (UCP)' do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, :publishable, store: store) }
  let(:context) do
    Spree::AgentTools::Context.new(
      store: store, api_key: api_key,
      request_headers: { 'HTTP_X_SPREE_API_KEY' => api_key.token, 'HTTP_HOST' => 'www.example.com' }
    )
  end

  let!(:product) { create(:product, store: store, status: 'active', name: 'Linen Shirt', price: 25) }
  let!(:variant) { create(:variant, product: product, price: 30) }
  let(:storefront) { 'https://shop.example.com' }

  # Stubbed rather than saved: the default store outlives the example.
  before { allow_any_instance_of(Spree::Store).to receive(:configured_storefront_url) { storefront } }

  def tool(name)
    Spree.store_agent_tools.available_for(context).find { |candidate| candidate.tool_name == name }
  end

  def line(variant, quantity = 1)
    { item: { id: variant.prefixed_id }, quantity: quantity }
  end

  def create_cart(*line_items)
    tool('create_cart').call(cart: { line_items: line_items })
  end

  describe 'the registry' do
    it 'offers the UCP shopping operations under the spec names' do
      names = Spree.store_agent_tools.available_for(context).map(&:tool_name)

      expect(names).to contain_exactly(
        'search_catalog', 'lookup_catalog', 'get_product',
        'create_cart', 'get_cart', 'update_cart', 'cancel_cart',
        'create_checkout', 'get_checkout', 'update_checkout', 'cancel_checkout',
        'get_order'
      )
    end

    it 'refuses a back-office tool' do
      expect { Spree.store_agent_tools << Spree::AgentTools::SearchResources }.to raise_error(ArgumentError)
    end
  end

  describe 'search_catalog' do
    it 'lists the catalog for an empty query' do
      result = tool('search_catalog').call(catalog: { query: '' })

      expect(result.dig(:ucp, :status)).to eq('success')
      expect(result[:products].map { |entry| entry[:id] }).to include(product.prefixed_id)
    end

    it 'prices variants in minor units with their currency' do
      found = tool('search_catalog').call(catalog: {})[:products].find { |entry| entry[:id] == product.prefixed_id }

      expect(found[:variants].map { |entry| entry[:id] }).to include(variant.prefixed_id)
      expect(found[:variants].find { |entry| entry[:id] == variant.prefixed_id }[:price]).to eq(amount: 3000, currency: 'USD')
      expect(found[:price_range][:min][:amount]).to be <= found[:price_range][:max][:amount]
    end

    it 'pages with an opaque cursor' do
      create(:product, store: store, status: 'active')

      first = tool('search_catalog').call(catalog: { pagination: { limit: 1 } })
      second = tool('search_catalog').call(catalog: { pagination: { limit: 1, cursor: first.dig(:pagination, :cursor) } })

      expect(first.dig(:pagination, :has_next_page)).to be(true)
      expect(second[:products].first[:id]).not_to eq(first[:products].first[:id])
    end
  end

  describe 'lookup_catalog' do
    it 'resolves a variant id to its product and says which variant matched' do
      result = tool('lookup_catalog').call(catalog: { ids: [variant.prefixed_id] })

      matched = result[:products].first[:variants].find { |entry| entry[:id] == variant.prefixed_id }
      expect(matched[:inputs]).to eq([{ id: variant.prefixed_id, match: 'exact' }])
    end

    it 'leaves an unknown id out and names it' do
      result = tool('lookup_catalog').call(catalog: { ids: [product.prefixed_id, 'prod_missing'] })

      expect(result[:products].size).to eq(1)
      expect(result[:messages]).to eq([{ type: 'info', code: 'not_found', content: 'prod_missing' }])
    end

    it 'reads every product in one request' do
      other = create(:product, store: store, status: 'active')
      expect_any_instance_of(Spree::AgentTools::ApiDispatch).to receive(:call).once.and_call_original

      result = tool('lookup_catalog').call(catalog: { ids: [variant.prefixed_id, other.prefixed_id] })

      expect(result[:products].size).to eq(2)
    end

    # An empty id filter is no filter: it would list the whole catalog.
    it 'lists nothing when no id names a product' do
      result = tool('lookup_catalog').call(catalog: { ids: ['prod_missing', 'variant_missing'] })

      expect(result[:products]).to be_empty
      expect(result[:messages].size).to eq(2)
    end

    it 'does not reach a variant of another store' do
      foreign = create(:variant, product: create(:product, store: create(:store), status: 'active'))

      result = tool('lookup_catalog').call(catalog: { ids: [foreign.prefixed_id] })

      expect(result[:products]).to be_empty
    end
  end

  describe 'get_product' do
    it 'answers not_found as a UCP error' do
      result = tool('get_product').call(catalog: { id: 'prod_missing' })

      expect(result.dig(:ucp, :status)).to eq('error')
      expect(result[:messages].first).to include(code: 'not_found', severity: 'unrecoverable')
    end
  end

  describe 'carts' do
    it 'uses the cart token as the id, never the guessable prefixed id' do
      result = create_cart(line(variant, 2))
      cart = store.carts.find_by!(token: result[:id])

      expect(result[:id]).not_to eq(cart.prefixed_id)
      expect(result[:line_items].first).to include(quantity: 2, item: include(id: variant.prefixed_id, price: 3000))
      expect(result[:totals]).to include({ type: 'subtotal', amount: 6000 }, { type: 'total', amount: 6000 })
      expect(result[:continue_url]).to include("token=#{cart.token}")
    end

    it 'refuses a product id with the fix, instead of guessing a variant' do
      result = create_cart({ item: { id: product.prefixed_id }, quantity: 1 })

      expect(result[:messages].first).to include(code: 'invalid_item', severity: 'recoverable',
                                                 path: '$.line_items[0].item.id')
      expect(store.carts.count).to eq(0)
    end

    it 'answers not_found for an unknown cart id' do
      expect(tool('get_cart').call(id: 'nope')[:messages].first[:code]).to eq('not_found')
    end

    it 'does not open a cart by its prefixed id' do
      cart = store.carts.find_by!(token: create_cart(line(variant))[:id])

      expect(tool('get_cart').call(id: cart.prefixed_id)[:messages].first[:code]).to eq('not_found')
    end

    it 'replaces the whole cart on update' do
      other = create(:variant, product: product, price: 10)
      id = create_cart(line(variant), line(other))[:id]

      result = tool('update_cart').call(id: id, cart: { line_items: [line(other, 3)] })

      expect(result[:line_items].map { |entry| [entry.dig(:item, :id), entry[:quantity]] }).to eq([[other.prefixed_id, 3]])
    end

    # Long-lived agent carts go stale. Completion re-prices inside its lock
    # whatever happens here, but an update re-sends every line, so the totals
    # an agent quotes after one are today's.
    it 're-prices every line on update, not only the ones that changed' do
      id = create_cart(line(variant))[:id]
      variant.set_price('USD', 40)

      result = tool('update_cart').call(id: id, cart: { line_items: [line(variant)] })

      expect(result[:line_items].first.dig(:item, :price)).to eq(4000)
    end

    it 'answers a cancellation with the cart as it was, then forgets it' do
      id = create_cart(line(variant))[:id]

      expect(tool('cancel_cart').call(id: id)[:line_items].size).to eq(1)
      expect(tool('get_cart').call(id: id)[:messages].first[:code]).to eq('not_found')
    end
  end

  describe 'checkout' do
    it 'hands the buyer to the store checkout, since nothing is paid in the agent' do
      cart_id = create_cart(line(variant))[:id]

      result = tool('create_checkout').call(checkout: { cart_id: cart_id, buyer: { email: 'buyer@example.com' } })

      expect(result[:id]).to eq(cart_id)
      expect(result[:status]).to eq('requires_escalation')
      expect(result[:continue_url]).to start_with("#{storefront}/cart/resume?")
      expect(result[:messages].first).to include(severity: 'requires_buyer_input')
      expect(result[:buyer]).to eq(email: 'buyer@example.com')
      expect(result.dig(:ucp, :payment_handlers)).to eq({})
    end

    # A store with no web storefront has nowhere to send the buyer, and a
    # link to the API's own address would only fail there.
    it 'says it cannot be finished here when the store has no web checkout' do
      allow_any_instance_of(Spree::Store).to receive(:configured_storefront_url).and_return(nil)

      result = tool('create_checkout').call(checkout: { line_items: [line(variant)] })

      expect(result[:status]).to eq('incomplete')
      expect(result).not_to have_key(:continue_url)
      expect(result[:messages].first).to include(code: 'checkout_unavailable')
    end

    it 'starts one from line items' do
      result = tool('create_checkout').call(checkout: { line_items: [line(variant)] })

      expect(result[:status]).to eq('requires_escalation')
      expect(store.carts.find_by(token: result[:id])).to be_present
    end

    context 'once the buyer has paid in the browser' do
      let(:order) { create(:completed_order_with_totals, store: store) }

      it 'reads as completed, carrying the order, and get_order answers for the same id' do
        cart = create(:cart, store: store, token: order.token, completed_at: Time.current)
        order.update_columns(cart_id: cart.id)

        checkout = tool('get_checkout').call(id: cart.token)
        placed = tool('get_order').call(id: cart.token)

        expect(checkout[:status]).to eq('completed')
        expect(checkout[:order]).to include(id: order.token, label: order.number,
                                            permalink_url: "#{storefront}/order-placed/#{cart.prefixed_id}")
        expect(checkout).not_to have_key(:continue_url)
        expect(placed).to include(id: order.token, currency: order.currency)
        expect(placed[:line_items].map { |entry| entry[:status] }).to all(eq('processing'))
        expect(tool('cancel_checkout').call(id: cart.token)[:messages].first[:code]).to eq('not_allowed')
      end
    end
  end

  describe 'malformed arguments' do
    it 'names the fix for an item sent as a bare id' do
      result = tool('create_cart').call(cart: { line_items: [{ item: variant.prefixed_id, quantity: 1 }] })

      expect(result[:messages].first).to include(code: 'invalid_item', severity: 'recoverable', path: '$.line_items[0].item')
    end

    it 'names the fix for a search sent as a string' do
      result = tool('search_catalog').call(catalog: 'shirts')

      expect(result[:messages].first).to include(code: 'invalid', path: '$.catalog')
    end

    it 'ignores a price filter that is not a number' do
      result = tool('search_catalog').call(catalog: { filters: { price: 1000 } })

      expect(result.dig(:ucp, :status)).to eq('success')
    end
  end

  describe 'search filters' do
    it 'filters by price in minor units' do
      dearer = create(:product, store: store, status: 'active', price: 50)

      result = tool('search_catalog').call(catalog: { filters: { price: { min: 4000 } } })

      expect(result[:products].map { |entry| entry[:id] }).to eq([dearer.prefixed_id])
    end
  end

  describe 'cancelling' do
    it 'leaves the cart alone when it could not be read first' do
      id = create_cart(line(variant))[:id]
      failed = Spree::AgentTools::ApiDispatch::Response.new(status: 500, body: { 'error' => { 'message' => 'Down' } }, headers: {})
      allow_any_instance_of(Spree::AgentTools::ApiDispatch).to receive(:call).and_wrap_original do |original, **options|
        options[:method] == :get ? failed : original.call(**options)
      end

      result = tool('cancel_cart').call(id: id)

      expect(result.dig(:ucp, :status)).to eq('error')
      expect(store.carts.find_by(token: id)).to be_present
    end
  end

  # The order's own record of what was sent, across every seller's order
  # when a checkout was divided — mapped from Store API payloads directly.
  describe Spree::AgentTools::Shopping::Ucp do
    def line_json(id, quantity)
      { 'id' => id, 'variant_id' => "variant_#{id}", 'name' => id, 'quantity' => quantity,
        'price' => '10.00', 'total' => (10 * quantity).to_s }
    end

    def order_json(items, fulfillments = [], **attributes)
      { 'number' => 'R1', 'currency' => 'USD', 'item_total' => '30.00', 'total' => '30.00',
        'completed_at' => '2026-10-20T10:00:00Z', 'items' => items, 'fulfillments' => fulfillments }.merge(attributes)
    end

    def fulfillment(status, items, **attributes)
      { 'id' => "ful_#{status}", 'status' => status, 'items' => items }.merge(attributes)
    end

    it 'counts what has shipped per line' do
      json = order_json(
        [line_json('a', 2), line_json('b', 1)],
        [fulfillment('fulfilled', [{ 'item_id' => 'a', 'quantity' => 1 }], 'fulfilled_at' => '2026-10-21T10:00:00Z',
                                                                             'tracking' => '1Z9')]
      )

      order = described_class.order(json, id: 'tok')

      expect(order[:line_items].map { |line| [line[:id], line[:status], line[:quantity][:fulfilled]] }).
        to eq([['a', 'partial', 1], ['b', 'processing', 0]])
      expect(order.dig(:fulfillment, :events).first).to include(type: 'shipped', tracking_number: '1Z9')
    end

    it 'marks every line removed on a cancelled order' do
      order = described_class.order(order_json([line_json('a', 1)], [], 'fulfillment_status' => 'canceled'), id: 'tok')

      expect(order[:line_items].first).to include(status: 'removed', quantity: include(total: 0))
    end

    it 'reads a multi-seller purchase as one, across its orders' do
      group = order_json([], [], 'orders' => [
                           order_json([line_json('a', 1)]),
                           order_json([line_json('b', 2)], [fulfillment('delivered', [{ 'item_id' => 'b', 'quantity' => 2 }],
                                                                        'fulfilled_at' => '2026-10-21T10:00:00Z',
                                                                        'delivered_at' => '2026-10-22T10:00:00Z')])
                         ]).except('items', 'fulfillments')

      order = described_class.order(group, id: 'tok')
      checkout = described_class.checkout(group, id: 'tok', continue_url: nil)

      expect(order[:line_items].map { |line| [line[:id], line[:status]] }).to eq([%w[a processing], %w[b fulfilled]])
      expect(order.dig(:fulfillment, :events).map { |event| event[:type] }).to eq(%w[shipped delivered])
      expect(checkout[:status]).to eq('completed')
      expect(checkout[:line_items].size).to eq(2)
    end
  end
end
