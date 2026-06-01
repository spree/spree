require 'spec_helper'

RSpec.describe Spree::Admin::ChannelsController, type: :controller do
  stub_authorization!
  render_views

  let!(:store) { Spree::Store.default }

  describe 'GET #index' do
    let!(:extra_channel) { create(:channel, store: store, code: 'pos', name: 'POS') }

    it 'renders the list of channels' do
      get :index

      expect(response).to be_successful
      expect(response).to render_template(:index)
      expect(assigns(:channels)).to include(extra_channel, store.default_channel)
    end
  end

  describe 'GET #new' do
    it 'renders the new channel form' do
      get :new

      expect(response).to be_successful
      expect(response).to render_template(:new)
    end
  end

  describe 'POST #create' do
    let(:channel_params) { { name: 'Wholesale', code: 'wholesale', active: '1' } }

    it 'creates a new channel scoped to the current store' do
      expect { post :create, params: { channel: channel_params } }.to change(Spree::Channel, :count).by(1)

      channel = Spree::Channel.last
      expect(channel.store).to eq(store)
      expect(channel.name).to eq('Wholesale')
      expect(channel.code).to eq('wholesale')
      expect(channel).to be_active
      expect(response).to redirect_to(spree.edit_admin_channel_path(channel))
    end
  end

  describe 'GET #edit' do
    let!(:channel) { create(:channel, store: store, code: 'pos', name: 'POS') }

    it 'renders the edit channel form' do
      get :edit, params: { id: channel.to_param }

      expect(response).to be_successful
      expect(response).to render_template(:edit)
    end
  end

  describe 'PUT #update' do
    let!(:channel) { create(:channel, store: store, code: 'pos', name: 'POS') }

    it 'updates the channel' do
      put :update, params: { id: channel.to_param, channel: { name: 'Point of Sale' } }

      expect(response).to redirect_to(spree.edit_admin_channel_path(channel))
      expect(channel.reload.name).to eq('Point of Sale')
    end
  end

  describe 'DELETE #destroy' do
    let!(:channel) { create(:channel, store: store, code: 'extra', name: 'Extra') }

    it 'deletes the channel' do
      delete :destroy, params: { id: channel.to_param }

      expect(response).to redirect_to(spree.admin_channels_path)
      expect { channel.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
