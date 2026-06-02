require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:product) { create(:product, status: 'active') }
  let!(:pos_channel) { create(:channel, store: store, code: 'pos', name: 'POS') }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'Spree::Api::V3::ChannelResolution' do
    # Read from the controller — Spree::Current resets per request and the
    # fallback path doesn't write through it.
    def resolved_channel
      controller.send(:current_channel)
    end

    it 'resolves channel from X-Spree-Channel header by code' do
      request.headers['x-spree-channel'] = 'pos'
      get :index

      expect(response).to have_http_status(:ok)
      expect(resolved_channel).to eq(pos_channel)
    end

    it 'resolves channel from X-Spree-Channel header by prefixed ID' do
      request.headers['x-spree-channel'] = pos_channel.prefixed_id
      get :index

      expect(response).to have_http_status(:ok)
      expect(resolved_channel).to eq(pos_channel)
    end

    it 'falls back to store default channel for an unknown prefixed ID' do
      request.headers['x-spree-channel'] = 'ch_nonexistent'
      get :index

      expect(response).to have_http_status(:ok)
      expect(resolved_channel).to eq(store.default_channel)
    end

    it 'falls back to store default channel when header is absent' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(resolved_channel).to eq(store.default_channel)
    end

    it 'falls back to store default channel for unknown channel code' do
      request.headers['x-spree-channel'] = 'no-such-channel'
      get :index

      expect(response).to have_http_status(:ok)
      expect(resolved_channel).to eq(store.default_channel)
    end

    it 'ignores inactive channels' do
      pos_channel.update!(active: false)
      request.headers['x-spree-channel'] = 'pos'
      get :index

      expect(response).to have_http_status(:ok)
      expect(resolved_channel).to eq(store.default_channel)
    end

    it 'scopes channel lookup to the current store' do
      other_store = create(:store, code: 'other')
      other_store.channels.create!(name: 'Other POS', code: 'pos')

      request.headers['x-spree-channel'] = 'pos'
      get :index

      expect(response).to have_http_status(:ok)
      expect(resolved_channel).to eq(pos_channel)
      expect(resolved_channel.store).to eq(store)
    end
  end
end
