require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::CartController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'POST #create' do
    it 'creates a new cart' do
      expect do
        post :create
      end.to change(Spree::Order, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['number']).to be_present
      expect(json_response['state']).to eq('cart')
    end

    it 'returns token for guest access' do
      post :create

      expect(json_response['token']).to be_present
    end

    it 'creates cart associated with current store' do
      post :create

      expect(Spree::Order.last.store_id).to eq(store.id)
    end

    it 'sets locale on the cart' do
      post :create

      expect(json_response['locale']).to be_present
      expect(Spree::Order.last.locale).to be_present
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
        expect(Spree::Order.last.user_id).to eq(user.id)
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
          line_items: [
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
          line_items: [{ variant_id: variant.prefixed_id, quantity: 3 }]
        }

        expect(response).to have_http_status(:created)
        expect(json_response['line_items'].size).to eq(1)
        expect(json_response['line_items'].first['quantity']).to eq(3)
      end

      it 'defaults quantity to 1 when not specified' do
        post :create, params: {
          line_items: [{ variant_id: variant.prefixed_id }]
        }

        expect(response).to have_http_status(:created)
        expect(Spree::Order.last.line_items.first.quantity).to eq(1)
      end

      it 'returns variant_not_found for invalid variant_id' do
        post :create, params: {
          line_items: [{ variant_id: 'variant_doesnotexist', quantity: 1 }]
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
        get :show

        expect(response).to have_http_status(:ok)
        expect(json_response['number']).to eq(cart.number)
        expect(json_response['state']).to eq('cart')
      end

      it 'returns cart with line items' do
        get :show

        expect(json_response['line_items']).to be_present
        expect(json_response['line_items'].size).to eq(cart.line_items.count)
      end

      it 'returns cart token in response' do
        get :show

        expect(json_response['token']).to eq(cart.token)
      end

      it 'returns not found for invalid token' do
        request.headers['x-spree-token'] = 'invalid_token'
        get :show

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end

      it 'returns not found for completed order token' do
        completed_order = create(:completed_order_with_totals, store: store)
        request.headers['x-spree-token'] = completed_order.token
        get :show

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end

      it 'returns not found for other store cart' do
        other_store = create(:store)
        other_cart = create(:order_with_line_items, store: other_store)
        request.headers['x-spree-token'] = other_cart.token
        get :show

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with JWT authentication' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      let!(:cart) { create(:order_with_line_items, user: user, store: store) }

      it 'returns the users cart' do
        get :show

        expect(response).to have_http_status(:ok)
        expect(json_response['number']).to eq(cart.number)
      end

      it 'returns the most recent cart when user has multiple' do
        # The let! cart was created first, so create a newer one
        cart # trigger let!
        newer_cart = nil

        # Create in a Timecop block to ensure proper timestamps
        Timecop.travel(1.hour.from_now) do
          newer_cart = create(:order_with_line_items, user: user, store: store)
        end

        get :show

        expect(response).to have_http_status(:ok)
        expect(json_response['number']).to eq(newer_cart.number)
      end

      it 'returns not found when user has no cart' do
        cart.update!(state: 'complete', completed_at: Time.current)

        get :show

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end

      it 'does not return other users cart' do
        other_user_cart = create(:order_with_line_items, store: store)
        cart.update!(state: 'complete', completed_at: Time.current)

        get :show

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      it 'returns not found without cart_token or JWT' do
        get :show

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        get :show

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_token')
      end
    end

    context 'response structure' do
      let(:cart) { create(:order_with_line_items, store: store) }

      before { request.headers['x-spree-token'] = cart.token }

      it 'returns expected cart attributes' do
        get :show

        expect(json_response).to include(
          'id',
          'number',
          'state',
          'token',
          'currency',
          'item_count',
          'item_total',
          'display_item_total',
          'total',
          'display_total'
        )
      end

      it 'returns line item attributes' do
        get :show

        line_item = json_response['line_items'].first
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
  end

  describe 'PATCH #associate' do
    let(:guest_cart) { create(:order_with_line_items, store: store, user: nil, email: 'guest@example.com') }

    context 'with JWT authentication' do
      before do
        request.headers['Authorization'] = "Bearer #{jwt_token}"
      end

      it 'associates guest cart with current user via x-spree-token header' do
        request.headers['x-spree-token'] = guest_cart.token
        patch :associate

        expect(response).to have_http_status(:ok)
        expect(guest_cart.reload.user).to eq(user)
        expect(json_response['number']).to eq(guest_cart.number)
      end

      it 'updates cart email to users email' do
        request.headers['x-spree-token'] = guest_cart.token
        patch :associate

        expect(response).to have_http_status(:ok)
        expect(guest_cart.reload.email).to eq(user.email)
      end

      it 'sets user addresses on cart when user has addresses' do
        bill = create(:address, firstname: 'Bill')
        ship = create(:address, firstname: 'Ship')
        user.update!(bill_address: bill, ship_address: ship)

        request.headers['x-spree-token'] = guest_cart.token
        patch :associate

        expect(response).to have_http_status(:ok)
        guest_cart.reload
        expect(guest_cart.bill_address).to be_present
        expect(guest_cart.ship_address).to be_present
      end

      it 'allows re-associating cart already owned by current user' do
        guest_cart.update!(user: user)

        request.headers['x-spree-token'] = guest_cart.token
        patch :associate

        expect(response).to have_http_status(:ok)
        expect(guest_cart.reload.user).to eq(user)
      end

      it 'returns not found for invalid token' do
        request.headers['x-spree-token'] = 'invalid_token'
        patch :associate

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end

      it 'returns not found without order token' do
        patch :associate

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end

      it 'returns not found for completed order' do
        completed_order = create(:completed_order_with_totals, store: store, user: nil)

        request.headers['x-spree-token'] = completed_order.token
        patch :associate

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end

      it 'returns not found when cart belongs to another user' do
        other_user = create(:user)
        other_user_cart = create(:order_with_line_items, store: store, user: other_user)

        request.headers['x-spree-token'] = other_user_cart.token
        patch :associate

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
        expect(other_user_cart.reload.user).to eq(other_user) # unchanged
      end

      it 'returns not found for cart from other store' do
        other_store = create(:store)
        other_store_cart = create(:order_with_line_items, store: other_store)

        request.headers['x-spree-token'] = other_store_cart.token
        patch :associate

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without JWT authentication' do
      it 'returns unauthorized' do
        request.headers['x-spree-token'] = guest_cart.token
        patch :associate

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        request.headers['x-spree-token'] = guest_cart.token
        patch :associate

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_token')
      end
    end
  end
end
