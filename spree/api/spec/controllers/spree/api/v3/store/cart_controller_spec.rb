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
    context 'with order_token parameter' do
      let(:cart) { create(:order_with_line_items, store: store) }

      it 'returns the cart' do
        get :show, params: { order_token: cart.token }

        expect(response).to have_http_status(:ok)
        expect(json_response['number']).to eq(cart.number)
        expect(json_response['state']).to eq('cart')
      end

      it 'returns cart with line items' do
        get :show, params: { order_token: cart.token }

        expect(json_response['line_items']).to be_present
        expect(json_response['line_items'].size).to eq(cart.line_items.count)
      end

      it 'returns cart token in response' do
        get :show, params: { order_token: cart.token }

        expect(json_response['token']).to eq(cart.token)
      end

      it 'returns not found for invalid token' do
        get :show, params: { order_token: 'invalid_token' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end

      it 'returns not found for completed order token' do
        completed_order = create(:completed_order_with_totals, store: store)
        get :show, params: { order_token: completed_order.token }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end

      it 'returns not found for other store cart' do
        other_store = create(:store)
        other_cart = create(:order_with_line_items, store: other_store)
        get :show, params: { order_token: other_cart.token }

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
      it 'returns not found without order_token or JWT' do
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

      it 'returns expected cart attributes' do
        get :show, params: { order_token: cart.token }

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
        get :show, params: { order_token: cart.token }

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

      it 'associates guest cart with current user via order_token param' do
        patch :associate, params: { order_token: guest_cart.token }

        expect(response).to have_http_status(:ok)
        expect(guest_cart.reload.user).to eq(user)
        expect(json_response['number']).to eq(guest_cart.number)
      end

      it 'associates guest cart with current user via x-spree-order-token header' do
        request.headers['x-spree-order-token'] = guest_cart.token

        patch :associate

        expect(response).to have_http_status(:ok)
        expect(guest_cart.reload.user).to eq(user)
      end

      it 'updates cart email to users email' do
        patch :associate, params: { order_token: guest_cart.token }

        expect(response).to have_http_status(:ok)
        expect(guest_cart.reload.email).to eq(user.email)
      end

      it 'sets user addresses on cart when user has addresses' do
        bill = create(:address, firstname: 'Bill')
        ship = create(:address, firstname: 'Ship')
        user.update!(bill_address: bill, ship_address: ship)

        patch :associate, params: { order_token: guest_cart.token }

        expect(response).to have_http_status(:ok)
        guest_cart.reload
        expect(guest_cart.bill_address).to be_present
        expect(guest_cart.ship_address).to be_present
      end

      it 'allows re-associating cart already owned by current user' do
        guest_cart.update!(user: user)

        patch :associate, params: { order_token: guest_cart.token }

        expect(response).to have_http_status(:ok)
        expect(guest_cart.reload.user).to eq(user)
      end

      it 'returns not found for invalid token' do
        patch :associate, params: { order_token: 'invalid_token' }

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

        patch :associate, params: { order_token: completed_order.token }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
      end

      it 'returns not found when cart belongs to another user' do
        other_user = create(:user)
        other_user_cart = create(:order_with_line_items, store: store, user: other_user)

        patch :associate, params: { order_token: other_user_cart.token }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('order_not_found')
        expect(other_user_cart.reload.user).to eq(other_user) # unchanged
      end

      it 'returns not found for cart from other store' do
        other_store = create(:store)
        other_store_cart = create(:order_with_line_items, store: other_store)

        patch :associate, params: { order_token: other_store_cart.token }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without JWT authentication' do
      it 'returns unauthorized' do
        patch :associate, params: { order_token: guest_cart.token }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        patch :associate, params: { order_token: guest_cart.token }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_token')
      end
    end
  end
end
