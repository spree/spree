require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:product) { create(:product, status: 'active') }
  let(:channel) { store.default_channel }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['X-Spree-Channel'] = channel.code
  end

  describe 'public storefront access (default)' do
    it 'shows prices to a guest' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].first['price']).to be_present
    end
  end

  describe 'prices_hidden storefront access' do
    before { channel.update!(preferred_storefront_access: 'prices_hidden') }

    it 'nulls the price for a guest' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].first['price']).to be_nil
    end

    it 'returns the price for an authenticated customer' do
      request.headers['Authorization'] = "Bearer #{jwt_token}"

      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].first['price']).to be_present
    end
  end

  describe 'login_required storefront access' do
    before { channel.update!(preferred_storefront_access: 'login_required') }

    it 'rejects a guest with 401' do
      get :index

      expect(response).to have_http_status(:unauthorized)
    end

    it 'allows an authenticated customer' do
      request.headers['Authorization'] = "Bearer #{jwt_token}"

      get :index

      expect(response).to have_http_status(:ok)
    end
  end
end

RSpec.describe Spree::Api::V3::Store::CartsController, type: :controller do
  include_context 'API v3 Store'

  let(:channel) { store.default_channel }
  let(:guest_cart) { create(:order, store: store, channel: channel, user: nil, email: 'guest@example.com') }
  let(:user_cart) { create(:order, store: store, channel: channel, user: user) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['X-Spree-Channel'] = channel.code
  end

  describe 'guest checkout gating (Order#guest_checkout_disallowed?)' do
    context 'when the channel forbids guest checkout' do
      before { channel.update!(preferred_guest_checkout: false) }

      it 'blocks a cart with no registered user' do
        expect(guest_cart.guest_checkout_disallowed?).to be true
      end

      it 'allows a cart owned by a user' do
        expect(user_cart.guest_checkout_disallowed?).to be false
      end
    end

    context 'when the channel allows guest checkout' do
      before { channel.update!(preferred_guest_checkout: true) }

      it 'does not block a guest cart' do
        expect(guest_cart.guest_checkout_disallowed?).to be false
      end
    end

    context 'when the channel hides prices from guests but allows guest checkout' do
      before { channel.update!(preferred_storefront_access: 'prices_hidden', preferred_guest_checkout: true) }

      it 'still blocks a guest cart — a buyer who cannot see prices cannot check out' do
        expect(guest_cart.guest_checkout_disallowed?).to be true
      end
    end
  end

  describe 'POST #complete' do
    before do
      allow(controller).to receive(:find_cart!) { controller.instance_variable_set(:@cart, guest_cart) }
    end

    context 'when the channel forbids guest checkout' do
      before { channel.update!(preferred_guest_checkout: false) }

      it 'rejects a guest with 401 before attempting completion' do
        post :complete, params: { id: guest_cart.prefixed_id }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end

# OrdersController inherits Store::BaseController — proves the login gate now
# covers the BaseController branch, not just Store::ResourceController.
RSpec.describe Spree::Api::V3::Store::OrdersController, type: :controller do
  include_context 'API v3 Store'

  let(:channel) { store.default_channel }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['X-Spree-Channel'] = channel.code
  end

  describe 'login_required gate' do
    before { channel.update!(preferred_storefront_access: 'login_required') }

    it 'rejects a guest with 401 before loading the order' do
      get :show, params: { id: 'order_missing' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lets an authenticated customer through the gate' do
      request.headers['Authorization'] = "Bearer #{jwt_token}"

      get :show, params: { id: 'order_missing' }

      # Passes the gate; the missing order yields a non-401 (404) response.
      expect(response).not_to have_http_status(:unauthorized)
    end
  end
end

# CountriesController opts out via allow_guest_storefront_access! — reference
# data must stay reachable so the login flow works on a login_required channel.
RSpec.describe Spree::Api::V3::Store::CountriesController, type: :controller do
  include_context 'API v3 Store'

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['X-Spree-Channel'] = store.default_channel.code
    store.default_channel.update!(preferred_storefront_access: 'login_required')
  end

  it 'stays open to guests despite login_required' do
    get :index

    expect(response).not_to have_http_status(:unauthorized)
  end
end
