require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::CartsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  let(:cart) { Spree::Order.last }

  describe 'GET #index' do
    context 'with JWT authentication' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      let!(:user_cart1) { create(:order, user: user, store: store) }
      let!(:user_cart2) { create(:order, user: user, store: store) }

      it 'returns the current users carts' do
        get :index

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].size).to eq(2)
        numbers = json_response['data'].map { |c| c['number'] }
        expect(numbers).to include(user_cart1.number, user_cart2.number)
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
        create(:order, user: other_user, store: store)

        get :index

        numbers = json_response['data'].map { |c| c['number'] }
        expect(numbers).to match_array([user_cart1.number, user_cart2.number])
      end

      it 'does not return guest carts' do
        create(:order, user: nil, store: store)

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
        create(:order, user: user, store: other_store)

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
      end.to change(Spree::Order, :count).by(1)

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

    context 'with metadata' do
      it 'creates a cart with metadata' do
        post :create, params: { metadata: { 'source' => 'mobile_app', 'campaign' => 'summer_sale' } }

        expect(response).to have_http_status(:created)
        order = Spree::Order.last
        expect(order.metadata).to eq({ 'source' => 'mobile_app', 'campaign' => 'summer_sale' })
      end

      it 'does not return metadata in response' do
        post :create, params: { metadata: { 'source' => 'mobile_app' } }

        expect(response).to have_http_status(:created)
        expect(json_response).not_to have_key('metadata')
        expect(json_response).not_to have_key('private_metadata')
      end
    end

    context 'for authenticated user' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'creates a cart associated with user' do
        post :create

        expect(response).to have_http_status(:created)
        expect(cart.user_id).to eq(user.id)
      end
    end

    context 'with line_items' do
      let(:product) { create(:product, stores: [store]) }
      let(:product2) { create(:product, stores: [store]) }
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
        order = Spree::Order.last
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
        expect(json_response['error']['message']).to include('variant_doesnotexist')
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
      let(:cart) { create(:order_with_line_items, store: store) }

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
        other_cart = create(:order_with_line_items, store: other_store)
        request.headers['x-spree-token'] = other_cart.token
        get :show, params: { id: other_cart.prefixed_id }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with JWT authentication' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      let!(:cart) { create(:order_with_line_items, user: user, store: store) }

      it 'returns the users cart' do
        get :show, params: { id: cart.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['number']).to eq(cart.number)
      end

      it 'returns forbidden when cart belongs to another user' do
        other_user = create(:user)
        other_cart = create(:order_with_line_items, user: other_user, store: store)

        get :show, params: { id: other_cart.prefixed_id }

        expect(response).to have_http_status(:forbidden)
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
      let(:cart) { create(:order_with_line_items, store: store) }

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
          'item_count',
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

    context 'auto-advance' do
      let(:user) { create(:user_with_addresses) }
      let(:cart) { create(:order_with_line_items, store: store, user: user) }
      let(:country) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US') }
      let!(:us_state) { country.states.find_by(abbr: 'NY') || create(:state, country: country, abbr: 'NY', name: 'New York') }
      let!(:zone) { create(:zone, zone_members: [Spree::ZoneMember.new(zoneable: country)]) }
      let!(:shipping_method) { create(:shipping_method, zones: [zone]) }

      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'generates shipments when address is present but shipments are empty' do
        address = create(:address, user: user, country: country, state: us_state)
        cart.update!(email: 'customer@example.com', ship_address: address)
        cart.shipments.delete_all
        cart.update_column(:state, 'address')
        cart.reload

        expect(cart.shipments).to be_empty

        get :show, params: { id: cart.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['shipments']).to be_present
      end

      it 'does not advance when no address is set' do
        cart.update!(ship_address: nil)
        cart.shipments.delete_all
        cart.reload

        get :show, params: { id: cart.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['shipments']).to be_empty
      end
    end
  end

  describe 'PATCH #update' do
    let(:user) { create(:user_with_addresses) }
    let!(:order) { create(:order_with_line_items, store: store, user: user) }
    let(:country) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US') }
    let!(:us_state) { country.states.find_by(abbr: 'NY') || create(:state, country: country, abbr: 'NY', name: 'New York') }
    let!(:zone) { create(:zone, zone_members: [Spree::ZoneMember.new(zoneable: country)]) }
    let!(:shipping_method) { create(:shipping_method, zones: [zone]) }

    before do
      request.headers['Authorization'] = "Bearer #{jwt_token}"
    end

    it 'accepts ship_address_id to use an existing address' do
      order.update!(email: 'customer@example.com')
      existing_address = user.addresses.first || create(:address, user: user, country: country, state: us_state)

      patch :update, params: { id: order.prefixed_id, ship_address_id: existing_address.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(order.reload.ship_address_id).to eq(existing_address.id)
    end

    it 'auto-advances to payment after address submission' do
      order.update!(email: 'customer@example.com')
      order.next # cart -> address
      order.reload
      expect(order.state).to eq('address')

      patch :update, params: {
        id: order.prefixed_id,
        ship_address: {
          firstname: 'John', lastname: 'Doe',
          address1: '123 Main St', city: 'New York',
          zipcode: '10001', country_iso: 'US', state_abbr: 'NY',
          phone: '555-1234'
        }
      }

      expect(response).to have_http_status(:ok)
      expect(json_response['current_step']).to eq('payment')
    end
  end

  describe 'PATCH #associate' do
    let(:guest_cart) { create(:order_with_line_items, store: store, user: nil, email: 'guest@example.com') }

    context 'with JWT authentication' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

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

      it 'allows re-associating cart already owned by current user' do
        guest_cart.update!(user: user)

        patch :associate, params: { id: guest_cart.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(guest_cart.reload.user).to eq(user)
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
        other_user_cart = create(:order_with_line_items, store: store, user: other_user)

        patch :associate, params: { id: other_user_cart.prefixed_id }

        expect(response).to have_http_status(:not_found)
        expect(other_user_cart.reload.user).to eq(other_user) # unchanged
      end

      it 'returns not found for cart from other store' do
        other_store = create(:store)
        other_store_cart = create(:order_with_line_items, store: other_store)

        patch :associate, params: { id: other_store_cart.prefixed_id }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without JWT authentication' do
      it 'returns unauthorized' do
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
    let(:cart) { create(:order_with_line_items, store: store) }

    context 'with x-spree-token header' do
      before { request.headers['x-spree-token'] = cart.token }

      it 'deletes the cart' do
        delete :destroy, params: { id: cart.prefixed_id }

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'with JWT authentication' do
      let!(:user_cart) { create(:order_with_line_items, user: user, store: store) }

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
    let(:order) { create(:order_with_line_items, user: user, store: store, state: 'confirm') }

    before do
      request.headers['Authorization'] = "Bearer #{jwt_token}"
    end

    it 'completes the checkout' do
      # Set up order so it can be completed
      create(:payment, order: order, amount: order.total, state: 'checkout')
      order.shipments.each { |s| s.update_column(:state, 'ready') }

      post :complete, params: { id: order.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(order.reload.state).to eq('complete')
    end

    context 'when order cannot be completed' do
      let(:incomplete_order) { create(:order_with_line_items, user: user, store: store, state: 'address') }

      it 'returns unprocessable entity' do
        post :complete, params: { id: incomplete_order.prefixed_id }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
