require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::ChannelController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:wholesale) do
    create(:channel, store: store, code: 'wholesale', name: 'Wholesale',
                     preferred_storefront_access: 'login_required',
                     preferred_guest_checkout: false)
  end

  before { request.headers['X-Spree-Api-Key'] = api_key.token }

  describe 'GET #show' do
    it 'returns the store default channel with resolved posture when no channel is requested' do
      get :show

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(store.default_channel.prefixed_id)
      expect(json_response['default']).to be true
      expect(json_response['storefront_access']).to eq('public')
      expect(json_response['guest_checkout']).to be true
    end

    it 'returns the header-resolved channel with resolved posture for a guest' do
      request.headers['X-Spree-Channel'] = wholesale.code

      get :show

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(wholesale.prefixed_id)
      expect(json_response['code']).to eq('wholesale')
      expect(json_response['default']).to be false
      expect(json_response['storefront_access']).to eq('login_required')
      expect(json_response['guest_checkout']).to be false
    end

    it 'returns the key-bound channel without any header' do
      bound_key = create(:api_key, :publishable, store: store, channel: wholesale)
      request.headers['X-Spree-Api-Key'] = bound_key.token

      get :show

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(wholesale.prefixed_id)
    end
  end
end
