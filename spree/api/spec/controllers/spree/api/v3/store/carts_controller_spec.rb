require 'spec_helper'

class TestAddressWithLandmarkSerializer < ::Spree::Api::V3::AddressSerializer
  attribute :landmark do |address|
    "near #{address.address1}"
  end
end

RSpec.describe Spree::Api::V3::Store::CartsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  let(:cart) { Spree::Cart.last }

  describe 'GET #index' do
    context 'with JWT authentication' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      let!(:user_cart1) { create(:cart, customer: user, store: store) }
      let!(:user_cart2) { create(:cart, customer: user, store: store) }

      it 'returns the current users carts' do
        get :index

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].size).to eq(2)
        numbers = json_response['data'].map { |c| c['number'] }
        expect(numbers).to include(user_cart1.number, user_cart2.number)
      end

      it 'excludes completed carts — a signed-in customer never re-adopts a finished checkout' do
        user_cart2.update_columns(completed_at: Time.current)

        get :index

        numbers = json_response['data'].map { |c| c['number'] }
        expect(numbers).to eq([user_cart1.number])
      end

      it 'scopes carts to the request channel — other channels never leak into a surface' do
        wholesale = create(:channel, store: store, code: 'wholesale')
        wholesale_cart = create(:cart, customer: user, store: store, channel: wholesale)

        get :index

        numbers = json_response['data'].map { |c| c['number'] }
        expect(numbers).not_to include(wholesale_cart.number)

        request.headers['X-Spree-Channel'] = 'wholesale'
        get :index

        numbers = json_response['data'].map { |c| c['number'] }
        expect(numbers).to eq([wholesale_cart.number])
      end

      it 'returns carts ordered by updated_at desc' do
        user_cart1.update_column(:updated_at, 1.hour.ago)
        user_cart2.update_column(:updated_at, Time.current)

        get :index

        numbers = json_response['data'].map { |c| c['number'] }
        expect(numbers).to eq([user_cart2.number, user_cart1.number])
      end

      it 'returns pagination metadata' do
        get :index

        expect(json_response['meta']).to include('page', 'count', 'pages')
      end

      it 'returns cart-prefixed IDs' do
        get :index

        json_response['data'].each do |cart_json|
          expect(cart_json['id']).to start_with('cart_')
        end
      end

      it 'does not return other users carts' do
        other_user = create(:user)
        create(:cart, customer: other_user, store: store)

        get :index

        numbers = json_response['data'].map { |c| c['number'] }
        expect(numbers).to match_array([user_cart1.number, user_cart2.number])
      end

      it 'does not return guest carts' do
        create(:cart, customer: nil, store: store)

        get :index

        numbers = json_response['data'].map { |c| c['number'] }
        expect(numbers).to match_array([user_cart1.number, user_cart2.number])
      end

      it 'does not return completed orders' do
        create(:completed_order_with_totals, user: user, store: store)

        get :index

        numbers = json_response['data'].map { |c| c['number'] }
        expect(numbers).to match_array([user_cart1.number, user_cart2.number])
      end

      it 'does not return carts from other stores' do
        other_store = create(:store)
        create(:cart, customer: user, store: other_store)

        get :index

        numbers = json_response['data'].map { |c| c['number'] }
        expect(numbers).to match_array([user_cart1.number, user_cart2.number])
      end
    end

    context 'without JWT authentication' do
      it 'returns unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST #create' do
    it 'creates a new cart' do
      expect do
        post :create
      end.to change(Spree::Cart, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['number']).to be_present
      expect(json_response['current_step']).to eq('address')
    end

    it 'returns token for guest access' do
      post :create

      expect(json_response['token']).to be_present
    end

    it 'creates cart associated with current store' do
      post :create

      expect(cart.store_id).to eq(store.id)
    end

    it 'sets locale on the cart' do
      post :create

      expect(json_response['locale']).to be_present
      expect(cart.locale).to be_present
    end

    it 'sets market from Spree::Current on the cart' do
      market = create(:market, store: store)
      allow(Spree::Current).to receive(:market).and_return(market)

      post :create

      expect(response).to have_http_status(:created)
      expect(json_response['market_id']).to eq(market.prefixed_id)
      expect(json_response['market']).to include('name' => market.name, 'currency' => market.currency)
      expect(cart.market).to eq(market)
    end

    context 'with X-Spree-Channel header' do
      let!(:pos_channel) { create(:channel, store: store, code: 'pos', name: 'POS') }

      it 'attributes the cart to the requested channel' do
        request.headers['X-Spree-Channel'] = 'pos'

        post :create

        expect(response).to have_http_status(:created)
        expect(cart.channel).to eq(pos_channel)
      end

      it 'falls back to the store default channel when the header is absent' do
        post :create

        expect(cart.channel).to eq(store.default_channel)
      end
    end

    context 'with metadata' do
      it 'creates a cart with metadata' do
        post :create, params: { metadata: { 'source' => 'mobile_app', 'campaign' => 'summer_sale' } }

        expect(response).to have_http_status(:created)
        order = Spree::Cart.last
        expect(order.metadata).to eq({ 'source' => 'mobile_app', 'campaign' => 'summer_sale' })
      end

      it 'does not return metadata in response' do
        post :create, params: { metadata: { 'source' => 'mobile_app' } }

        expect(response).to have_http_status(:created)
        expect(json_response).not_to have_key('metadata')
      end
    end

    context 'for authenticated user' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'creates a cart associated with user' do
        post :create

        expect(response).to have_http_status(:created)
        expect(cart.customer_id).to eq(user.id)
      end
    end

    context 'with line_items' do
      let(:product) { create(:product) }
      let(:product2) { create(:product) }
      let(:variant) { create(:variant, product: product) }
      let(:variant2) { create(:variant, product: product2) }

      before do
        [variant, variant2].each do |v|
          v.stock_items.first.update!(count_on_hand: 10)
        end
      end

      it 'creates a cart with line items' do
        post :create, params: {
          items: [
            { variant_id: variant.prefixed_id, quantity: 2 },
            { variant_id: variant2.prefixed_id, quantity: 1 }
          ]
        }

        expect(response).to have_http_status(:created)
        order = Spree::Cart.last
        expect(order.line_items.count).to eq(2)
        expect(order.line_items.find_by(variant: variant).quantity).to eq(2)
        expect(order.line_items.find_by(variant: variant2).quantity).to eq(1)
      end

      it 'returns line items in response' do
        post :create, params: {
          items: [{ variant_id: variant.prefixed_id, quantity: 3 }]
        }

        expect(response).to have_http_status(:created)
        expect(json_response['items'].size).to eq(1)
        expect(json_response['items'].first['quantity']).to eq(3)
      end

      it 'defaults quantity to 1 when not specified' do
        post :create, params: {
          items: [{ variant_id: variant.prefixed_id }]
        }

        expect(response).to have_http_status(:created)
        expect(cart.line_items.first.quantity).to eq(1)
      end

      it 'returns variant_not_found for invalid variant_id' do
        post :create, params: {
          items: [{ variant_id: 'variant_doesnotexist', quantity: 1 }]
        }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('variant_not_found')
        expect(json_response['error']['message']).to eq('Variant not found')
      end
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        post :create

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_token')
        expect(json_response['error']['message']).to be_present
      end
    end
  end

  describe 'GET #show' do
    context 'with x-spree-token header' do
      let(:cart) { create(:cart_with_line_items, store: store) }

      before { request.headers['x-spree-token'] = cart.token }

      it 'returns the cart' do
        get :show, params: { id: cart.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['number']).to eq(cart.number)
        expect(json_response['current_step']).to eq('address')
      end

      it 'returns cart with line items' do
        get :show, params: { id: cart.prefixed_id }

        expect(json_response['items']).to be_present
        expect(json_response['items'].size).to eq(cart.items.count)
      end

      it 'returns cart token in response' do
        get :show, params: { id: cart.prefixed_id }

        expect(json_response['token']).to eq(cart.token)
      end

      it 'returns not found for invalid id' do
        get :show, params: { id: 'cart_invalid' }

        expect(response).to have_http_status(:not_found)
      end

      it 'returns not found for completed order' do
        completed_order = create(:completed_order_with_totals, store: store)
        get :show, params: { id: completed_order.prefixed_id }

        expect(response).to have_http_status(:not_found)
      end

      it 'returns not found for other store cart' do
        other_store = create(:store)
        other_cart = create(:cart_with_line_items, store: other_store)
        request.headers['x-spree-token'] = other_cart.token
        get :show, params: { id: other_cart.prefixed_id }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with JWT authentication' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      let!(:cart) { create(:cart_with_line_items, customer: user, store: store) }

      it 'returns the users cart' do
        get :show, params: { id: cart.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['number']).to eq(cart.number)
      end

      it 'returns forbidden when cart belongs to another user' do
        other_user = create(:user)
        other_cart = create(:cart_with_line_items, customer: other_user, store: store)

        get :show, params: { id: other_cart.prefixed_id }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with a completed cart' do
      let(:cart) { create(:cart_with_line_items, store: store) }

      before do
        cart.update_columns(completed_at: Time.current)
        request.headers['x-spree-token'] = cart.token
      end

      # The storefront contract: a completed cart is not a cart anymore —
      # 404 tells the client to drop its stale cart cookie.
      it 'returns not found' do
        get :show, params: { id: cart.prefixed_id }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      it 'returns not found for nonexistent cart' do
        get :show, params: { id: 'cart_nonexistent' }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        get :show, params: { id: 'cart_anything' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_token')
      end
    end

    context 'response structure' do
      let(:cart) { create(:cart_with_line_items, store: store) }

      before { request.headers['x-spree-token'] = cart.token }

      it 'returns expected cart attributes' do
        get :show, params: { id: cart.prefixed_id }

        expect(json_response).to include(
          'id',
          'number',
          'current_step',
          'completed_steps',
          'requirements',
          'token',
          'currency',
          'total_quantity',
          'item_total',
          'display_item_total',
          'total',
          'display_total'
        )
        expect(json_response).not_to have_key('state')
        expect(json_response).not_to have_key('checkout_steps')
        expect(json_response).not_to have_key('state_lock_version')
      end

      it 'returns line item attributes' do
        get :show, params: { id: cart.prefixed_id }

        line_item = json_response['items'].first
        expect(line_item).to include(
          'id',
          'variant_id',
          'quantity',
          'name',
          'price',
          'display_price',
          'total',
          'display_total'
        )
      end
    end

    context 'warnings' do
      let(:cart) { create(:cart_with_line_items, store: store) }

      before { request.headers['x-spree-token'] = cart.token }

      it 'returns empty warnings array when cart is valid' do
        get :show, params: { id: cart.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['warnings']).to eq([])
      end

      it 'returns warnings when a line item is out of stock' do
        cart.line_items.first.variant.stock_items.update_all(count_on_hand: 0, backorderable: false)

        get :show, params: { id: cart.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['warnings']).to be_an(Array)
        expect(json_response['warnings'].length).to eq(1)

        warning = json_response['warnings'].first
        expect(warning['code']).to eq('line_item_removed')
        expect(warning['message']).to be_present
        expect(warning['variant_id']).to start_with('variant_')
        expect(warning['line_item_id']).to start_with('li_')
      end

      it 'returns warnings when a product is discontinued' do
        cart.line_items.first.product.update_columns(status: 'discontinued')

        get :show, params: { id: cart.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['warnings'].length).to eq(1)
        expect(json_response['warnings'].first['code']).to eq('line_item_removed')
      end

      it 'removes the line item when returning a warning' do
        cart.line_items.first.variant.stock_items.update_all(count_on_hand: 0, backorderable: false)
        original_item_count = cart.line_items.count

        get :show, params: { id: cart.prefixed_id }

        expect(json_response['items'].length).to eq(original_item_count - 1)
      end
    end

    context 'auto-advance' do
      let(:user) { create(:user_with_addresses) }
      let(:cart) { create(:cart_with_line_items, store: store, customer: user) }
      let(:country) { Spree::Country.by_iso('US') }
      let!(:us_state) { Spree::State.resolve(country.iso, 'NY') }
      let!(:zone) { create(:zone) }
      let!(:shipping_method) { create(:shipping_method) }

      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'generates shipments when address is present but shipments are empty' do
        address = create(:address, user: user, country: country, state: us_state)
        cart.update!(email: 'customer@example.com', ship_address: address)
        cart.fulfillments.delete_all
        cart.reload

        expect(cart.fulfillments).to be_empty

        get :show, params: { id: cart.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['fulfillments']).to be_present
      end

      it 'surfaces a delivery_unavailable warning when the cart cannot be delivered' do
        address = create(:address, user: user, country: country, state: us_state)
        cart.update!(email: 'customer@example.com', ship_address: address)
        cart.fulfillments.delete_all
        # Give the products a fulfillment type no delivery method serves.
        unserved_profile = create(:delivery_profile, store: store, name: "Unserved #{SecureRandom.hex(4)}")
        cart.line_items.each { |line_item| line_item.variant.product.update!(delivery_profile: unserved_profile) }
        cart.reload

        get :show, params: { id: cart.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['fulfillments']).to be_empty
        expect(json_response['warnings'].map { |warning| warning['code'] }).to include('delivery_unavailable')
        expect(json_response['requirements']).to include(
          a_hash_including('step' => 'delivery', 'field' => 'delivery_method')
        )
      end

      it 'does not advance when no address is set' do
        cart.update!(ship_address: nil)
        cart.fulfillments.delete_all
        cart.reload

        get :show, params: { id: cart.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['fulfillments']).to be_empty
      end
    end

    context 'with a custom address serializer' do
      let(:cart) { create(:cart_with_line_items, store: store) }

      before { request.headers['x-spree-token'] = cart.token }

      around do |example|
        # Force the cart serializer to load before swapping the dependency, mirroring
        # the real-world boot order where serializers are loaded before a host app's
        # initializer overrides Spree.api.address_serializer. Without lazy resolution
        # the eager `resource:` binding would have already captured the default class.
        Spree::Api::V3::CartSerializer
        original = Spree.api.address_serializer
        Spree.api.address_serializer = TestAddressWithLandmarkSerializer
        example.run
        Spree.api.address_serializer = original
      end

      it 'serializes the billing address with the configured serializer' do
        cart.update!(bill_address: create(:address))
        get :show, params: { id: cart.prefixed_id, expand: 'billing_address' }

        expect(response).to have_http_status(:ok)
        address_json = json_response['billing_address']
        expect(address_json['address1']).to eq(cart.bill_address.address1)
        expect(address_json['landmark']).to eq("near #{cart.bill_address.address1}")
      end
    end
  end

  describe 'PATCH #update' do
    let(:user) { create(:user_with_addresses) }
    let!(:order) { create(:cart_with_line_items, store: store, customer: user) }
    let(:country) { Spree::Country.by_iso('US') }
    let!(:us_state) { Spree::State.resolve(country.iso, 'NY') }
    let!(:zone) { create(:zone) }
    let!(:shipping_method) { create(:shipping_method) }

    before do
      request.headers['Authorization'] = "Bearer #{jwt_token}"
    end

    it 'accepts shipping_address_id to use an existing address' do
      order.update!(email: 'customer@example.com')
      existing_address = user.addresses.first || create(:address, user: user, country: country, state: us_state)

      patch :update, params: { id: order.prefixed_id, shipping_address_id: existing_address.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(order.reload.ship_address_id).to eq(existing_address.id)
    end

    context 'selecting a pickup location' do
      let!(:pickup_location) { create(:stock_location, pickup_enabled: true, store: store) }

      it 'persists the choice and returns it as a prefixed id' do
        patch :update, params: { id: order.prefixed_id, preferred_stock_location_id: pickup_location.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(order.reload.preferred_stock_location).to eq(pickup_location)
        expect(json_response['preferred_stock_location_id']).to eq(pickup_location.prefixed_id)
      end

      it 'returns 404 for a location that is not pickup-enabled' do
        not_pickup = create(:stock_location, pickup_enabled: false, store: store)

        patch :update, params: { id: order.prefixed_id, preferred_stock_location_id: not_pickup.prefixed_id }

        expect(response).to have_http_status(:not_found)
        expect(order.reload.preferred_stock_location_id).to be_nil
      end
    end

    context 'when a line item cannot be delivered to the address' do
      let(:address) { user.addresses.first || create(:address, user: user, country: country, state: us_state) }
      let(:unserved_profile) { create(:delivery_profile, store: store, name: "Unserved #{SecureRandom.hex(4)}") }

      before do
        order.update!(email: 'customer@example.com')
        order.line_items.each { |line_item| line_item.variant.product.update!(delivery_profile: unserved_profile) }
      end

      it 'returns ok with a delivery_unavailable warning, an unmet delivery requirement, and no fulfillments' do
        patch :update, params: { id: order.prefixed_id, shipping_address_id: address.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['fulfillments']).to be_empty
        expect(json_response['warnings'].map { |warning| warning['code'] }).to include('delivery_unavailable')
        expect(json_response['requirements']).to include(
          a_hash_including('step' => 'delivery', 'field' => 'delivery_method')
        )
      end
    end

    context 'updating market' do
      let!(:market) { store.default_market }

      it 'updates the cart market' do
        patch :update, params: { id: order.prefixed_id, market_id: market.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['market_id']).to eq(market.prefixed_id)
        expect(json_response['market']).to include('name' => market.name)
        expect(order.reload.market).to eq(market)
      end

      it 'switches to a different market' do
        order.update!(market: market)

        de_country = create(:country, iso: 'DE', name: 'Germany')
        eu_market = create(:market, :eu, store: store, countries: [de_country])

        patch :update, params: { id: order.prefixed_id, market_id: eu_market.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['market_id']).to eq(eu_market.prefixed_id)
        expect(json_response['market']).to include('name' => eu_market.name, 'currency' => eu_market.currency)
        expect(order.reload.market).to eq(eu_market)
      end

      it 'returns not found for invalid market_id' do
        patch :update, params: { id: order.prefixed_id, market_id: 'mkt_invalid' }

        expect(response).to have_http_status(:not_found)
      end

      it 'auto-switches market when currency changes' do
        order.update!(market: market)

        de_country = create(:country, iso: 'DE', name: 'Germany')
        eu_market = create(:market, :eu, store: store, countries: [de_country])

        patch :update, params: { id: order.prefixed_id, currency: 'EUR' }

        expect(response).to have_http_status(:ok)
        expect(json_response['currency']).to eq('EUR')
        expect(json_response['market_id']).to eq(eu_market.prefixed_id)
      end

      it 'keeps the current market when no market exists for the currency' do
        order.update!(market: market)

        patch :update, params: { id: order.prefixed_id, currency: 'GBP' }

        # GBP is store-supported via the legacy column; without a GBP market
        # the cart keeps its current market.
        expect(response).to have_http_status(:ok)
        expect(json_response['currency']).to eq('GBP')
        expect(json_response['market_id']).to eq(market.prefixed_id)
      end
    end

    it 'auto-advances to payment after address submission' do
      order.update!(email: 'customer@example.com')
            order.reload
      

      patch :update, params: {
        id: order.prefixed_id,
        shipping_address: {
          first_name: 'John', last_name: 'Doe',
          address1: '123 Main St', city: 'New York',
          postal_code: '10001', country_iso: 'US', state_abbr: 'NY',
          phone: '555-1234'
        }
      }

      expect(response).to have_http_status(:ok)
      expect(json_response['current_step']).to eq('payment')
    end

    context 'stock reservations' do
      let(:address_params) do
        {
          first_name: 'Buyer', last_name: 'McGee',
          address1: '1 Test St', city: 'New York',
          postal_code: '10001', country_iso: 'US', state_abbr: 'NY',
          phone: '555-0100'
        }
      end

      before do
        order.line_items.first.variant.stock_items.first.update!(backorderable: false)
        order.line_items.first.variant.stock_items.first.set_count_on_hand(20)
      end

      it 'creates a reservation when the cart leaves the cart state' do
        expect {
          patch :update, params: { id: order.prefixed_id, email: 'customer@example.com', shipping_address: address_params }
        }.to change { Spree::StockReservation.for_order(order).count }.by_at_least(1)
      end

      it 'extends an existing reservation on subsequent in-checkout updates' do
        patch :update, params: { id: order.prefixed_id, email: 'customer@example.com', shipping_address: address_params }
        original_expiry = Spree::StockReservation.for_order(order).maximum(:expires_at)

        Timecop.freeze(2.minutes.from_now) do
          patch :update, params: { id: order.prefixed_id, customer_note: 'please ring bell' }
        end

        expect(Spree::StockReservation.for_order(order).maximum(:expires_at)).to be > original_expiry
      end

      context 'when stock_reservations_enabled is false' do
        before { stub_store_preferences(stock_reservations_enabled: false) }

        it 'does not create reservations' do
          order.update!(email: 'customer@example.com')

          expect {
            patch :update, params: { id: order.prefixed_id, shipping_address: address_params }
          }.not_to change { Spree::StockReservation.count }
        end
      end
    end
  end

  describe 'PATCH #associate' do
    let(:guest_cart) { create(:cart_with_line_items, store: store, customer: nil, email: 'guest@example.com') }

    context 'with JWT authentication' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      context 'with the guest cart token' do
        before { request.headers['x-spree-token'] = guest_cart.token }

        it 'associates guest cart with current user' do
          patch :associate, params: { id: guest_cart.prefixed_id }

          expect(response).to have_http_status(:ok)
          expect(guest_cart.reload.user).to eq(user)
          expect(json_response['number']).to eq(guest_cart.number)
        end

        it 'updates cart email to users email' do
          patch :associate, params: { id: guest_cart.prefixed_id }

          expect(response).to have_http_status(:ok)
          expect(guest_cart.reload.email).to eq(user.email)
        end

        it 'sets user addresses on cart when user has addresses' do
          bill = create(:address, firstname: 'Bill')
          ship = create(:address, firstname: 'Ship')
          user.update!(bill_address: bill, ship_address: ship)

          patch :associate, params: { id: guest_cart.prefixed_id }

          expect(response).to have_http_status(:ok)
          guest_cart.reload
          expect(guest_cart.bill_address).to be_present
          expect(guest_cart.ship_address).to be_present
        end
      end

      it 'allows re-associating a cart already owned by current user with its token' do
        guest_cart.update!(user: user)
        request.headers['x-spree-token'] = guest_cart.token

        patch :associate, params: { id: guest_cart.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(guest_cart.reload.user).to eq(user)
      end

      it 'forbids associating a cart without the cart token' do
        patch :associate, params: { id: guest_cart.prefixed_id }

        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['code']).to eq('access_denied')
        expect(guest_cart.reload.user).to be_nil
      end

      it 'forbids associating an own cart without the cart token' do
        guest_cart.update!(user: user)

        patch :associate, params: { id: guest_cart.prefixed_id }

        expect(response).to have_http_status(:forbidden)
      end

      it 'forbids associating a cart with the wrong cart token' do
        request.headers['x-spree-token'] = 'not-the-real-token'

        patch :associate, params: { id: guest_cart.prefixed_id }

        expect(response).to have_http_status(:forbidden)
        expect(guest_cart.reload.user).to be_nil
      end

      it 'returns not found for invalid id' do
        patch :associate, params: { id: 'cart_invalid' }

        expect(response).to have_http_status(:not_found)
      end

      it 'returns not found for completed order' do
        completed_order = create(:completed_order_with_totals, store: store, user: nil)

        patch :associate, params: { id: completed_order.prefixed_id }

        expect(response).to have_http_status(:not_found)
      end

      it 'returns not found when cart belongs to another user' do
        other_user = create(:user)
        other_user_cart = create(:cart_with_line_items, store: store, customer: other_user)

        patch :associate, params: { id: other_user_cart.prefixed_id }

        expect(response).to have_http_status(:not_found)
        expect(other_user_cart.reload.user).to eq(other_user) # unchanged
      end

      it 'returns not found for cart from other store' do
        other_store = create(:store)
        other_store_cart = create(:cart_with_line_items, store: other_store)

        patch :associate, params: { id: other_store_cart.prefixed_id }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without JWT authentication' do
      it 'returns unauthorized' do
        request.headers['x-spree-token'] = guest_cart.token

        patch :associate, params: { id: guest_cart.prefixed_id }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        patch :associate, params: { id: guest_cart.prefixed_id }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:cart) { create(:cart_with_line_items, store: store) }

    context 'with x-spree-token header' do
      before { request.headers['x-spree-token'] = cart.token }

      it 'deletes the cart' do
        delete :destroy, params: { id: cart.prefixed_id }

        expect(response).to have_http_status(:no_content)
      end

      it 'removes any stock reservations belonging to the cart' do
        line_item = cart.line_items.first
        line_item.variant.stock_items.first.update!(backorderable: false)
        line_item.variant.stock_items.first.set_count_on_hand(20)
        create(
          :stock_reservation,
          stock_item: line_item.variant.stock_items.first,
          line_item: line_item,
          cart: cart,
          order: nil,
          quantity: line_item.quantity,
          expires_at: 5.minutes.from_now
        )

        expect { delete :destroy, params: { id: cart.prefixed_id } }
          .to change { Spree::StockReservation.where(cart_id: cart.id).count }.from(1).to(0)
      end
    end

    context 'with JWT authentication' do
      let!(:user_cart) { create(:cart_with_line_items, customer: user, store: store) }

      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'deletes the users cart' do
        delete :destroy, params: { id: user_cart.prefixed_id }

        expect(response).to have_http_status(:no_content)
      end
    end
  end

  describe 'POST #complete' do
    let(:order) do
      cart = create(:cart_with_line_items, customer: user, store: store)
      cart.update!(email: user.email, ship_address: create(:address), bill_address: create(:address))
      cart.rebuild_fulfillments!
      cart.set_fulfillments_cost
      cart
    end

    before do
      request.headers['Authorization'] = "Bearer #{jwt_token}"
      create(:shipping_method) if Spree::DeliveryMethod.none?
    end

    it 'completes the checkout' do
      create(:payment, cart: order, amount: order.reload.total)

      post :complete, params: { id: order.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(order.reload.completed_at).to be_present
      expect(order.order).to be_present
    end

    it 'releases stock reservations on successful completion' do
      create(:payment, cart: order, amount: order.reload.total)
      line_item = order.line_items.first
      line_item.variant.stock_items.first.update!(backorderable: false)
      line_item.variant.stock_items.first.set_count_on_hand(20)
      create(
        :stock_reservation,
        stock_item: line_item.variant.stock_items.first,
        line_item: line_item,
        cart: order,
        order: nil,
        quantity: line_item.quantity,
        expires_at: 5.minutes.from_now
      )

      expect { post :complete, params: { id: order.prefixed_id } }
        .to change { Spree::StockReservation.for_order(order).count }.from(1).to(0)
    end

    context 'when order cannot be completed' do
      let(:incomplete_order) { create(:cart_with_line_items, customer: user, store: store) }

      it 'returns unprocessable entity with cart_cannot_complete code' do
        post :complete, params: { id: incomplete_order.prefixed_id }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('cart_cannot_complete')
      end
    end

    context 'when order was already completed by the gateway' do
      let(:completed_order) { create(:completed_order_with_totals, user: user, store: store) }

      it 'returns the completed order via JWT' do
        post :complete, params: { id: completed_order.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['number']).to eq(completed_order.number)
      end

      it 'returns the completed order via spree token' do
        request.headers['Authorization'] = nil
        request.headers['x-spree-token'] = completed_order.token

        post :complete, params: { id: completed_order.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['number']).to eq(completed_order.number)
      end

      it 'returns forbidden without valid authentication' do
        request.headers['Authorization'] = nil

        post :complete, params: { id: completed_order.prefixed_id }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with guest cart token' do
      let(:guest_order) do
        cart = create(:cart_with_line_items, customer: nil, store: store, email: 'guest@example.com')
        cart.update!(ship_address: create(:address), bill_address: create(:address))
        cart.rebuild_fulfillments!
        cart.set_fulfillments_cost
        cart
      end

      it 'completes via spree token' do
        create(:shipping_method) if Spree::DeliveryMethod.none?
        request.headers['Authorization'] = nil
        request.headers['x-spree-token'] = guest_order.token

        create(:payment, cart: guest_order, order: nil, amount: guest_order.reload.total)

        post :complete, params: { id: guest_order.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(guest_order.reload.completed_at).to be_present
      end
    end
  end
end
