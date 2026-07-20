require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:wholesale) do
    create(:channel, store: store, code: 'wholesale', name: 'Wholesale',
                     preferred_storefront_access: 'login_required',
                     preferred_guest_checkout: false)
  end
  let(:bound_key) { create(:api_key, :publishable, store: store, channel: wholesale) }

  let!(:dtc_product) { create(:product, status: 'active', name: 'DTC Only') }
  let!(:wholesale_product) do
    create(:product, status: 'active', name: 'Wholesale Only').tap do |product|
      store.default_channel.remove_products([product.id])
      wholesale.add_products([product.id])
    end
  end

  describe 'channel-bound publishable key' do
    before { request.headers['X-Spree-Api-Key'] = bound_key.token }

    it 'resolves the bound channel ahead of the storefront gate (guest gets 401 without any header)' do
      get :index

      expect(response).to have_http_status(:unauthorized)
    end

    it 'scopes the catalog to the bound channel for an authenticated customer' do
      request.headers['Authorization'] = "Bearer #{jwt_token}"

      get :index

      names = json_response['data'].map { |p| p['name'] }
      expect(names).to include('Wholesale Only')
      expect(names).not_to include('DTC Only')
    end

    it 'accepts a header naming the bound channel' do
      request.headers['Authorization'] = "Bearer #{jwt_token}"
      request.headers['X-Spree-Channel'] = wholesale.code

      get :index

      expect(response).to have_http_status(:ok)
    end

    it 'rejects a header naming a different channel with 422 channel_mismatch' do
      request.headers['Authorization'] = "Bearer #{jwt_token}"
      request.headers['X-Spree-Channel'] = store.default_channel.code

      get :index

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('channel_mismatch')
    end

    it 'rejects requests with 403 channel_inactive when the bound channel is deactivated' do
      wholesale.update!(active: false)
      request.headers['Authorization'] = "Bearer #{jwt_token}"

      get :index

      expect(response).to have_http_status(:forbidden)
      expect(json_response['error']['code']).to eq('channel_inactive')
    end
  end

  # Regression coverage for callback order in Store::ResourceController:
  # +set_resource+ must run AFTER channel resolution and the storefront gate.
  describe 'show under a header-resolved channel' do
    before { request.headers['X-Spree-Api-Key'] = api_key.token }

    it 'finds a product published only to the header channel' do
      request.headers['Authorization'] = "Bearer #{jwt_token}"
      request.headers['X-Spree-Channel'] = wholesale.code

      get :show, params: { id: wholesale_product.slug }

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Wholesale Only')
    end

    it 'gates a guest with 401 before revealing whether a resource exists' do
      request.headers['X-Spree-Channel'] = wholesale.code

      get :show, params: { id: 'no-such-product' }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
