# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Admin::ApiKeysController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }

  describe 'GET #index' do
    subject(:index) { get :index }

    let!(:api_keys) { create_list(:api_key, 3, store: store) }
    let!(:other_store_keys) { create_list(:api_key, 2, store: create(:store)) }

    it 'renders the index template' do
      index

      expect(response).to render_template(:index)
    end

    it 'assigns api keys for current store only' do
      index

      expect(assigns[:collection]).to contain_exactly(*api_keys)
    end
  end

  describe 'GET #show' do
    subject(:show) { get :show, params: { id: api_key.to_param } }

    let(:api_key) { create(:api_key, store: store) }

    it 'renders the show template' do
      show

      expect(response).to render_template(:show)
    end

    it 'assigns the api key' do
      show

      expect(assigns[:api_key]).to eq(api_key)
    end
  end

  describe 'GET #new' do
    subject(:new_action) { get :new }

    it 'renders the new template' do
      new_action

      expect(response).to render_template(:new)
    end

    it 'assigns a new api key' do
      new_action

      expect(assigns[:api_key]).to be_a_new(Spree::ApiKey)
    end
  end

  describe 'POST #create' do
    subject(:create_key) { post :create, params: { api_key: key_params } }

    let(:key_params) do
      {
        name: 'My API Key',
        key_type: 'publishable'
      }
    end

    it 'creates a new api key' do
      expect { create_key }.to change(Spree::ApiKey, :count).by(1)
    end

    it 'sets the attributes correctly' do
      create_key

      api_key = Spree::ApiKey.last
      expect(api_key.name).to eq('My API Key')
      expect(api_key.key_type).to eq('publishable')
      expect(api_key.store).to eq(store)
    end

    it 'generates a token with correct prefix' do
      create_key

      api_key = Spree::ApiKey.last
      expect(api_key.token).to start_with('pk_')
    end

    it 'redirects to show page' do
      create_key

      expect(response).to redirect_to(spree.admin_api_key_path(Spree::ApiKey.last))
    end

    context 'with secret key type' do
      let(:key_params) do
        {
          name: 'Secret Key',
          key_type: 'secret'
        }
      end

      it 'stores token_digest and token_prefix instead of plaintext token' do
        create_key

        api_key = Spree::ApiKey.last
        expect(api_key.token).to be_nil
        expect(api_key.token_digest).to be_present
        expect(api_key.token_prefix).to start_with('sk_')
      end

      it 'passes plaintext_token via flash for one-time display' do
        create_key

        expect(flash[:plaintext_token]).to start_with('sk_')
        expect(response).to redirect_to(spree.admin_api_key_path(Spree::ApiKey.last))
      end
    end

    context 'with invalid params' do
      let(:key_params) { { name: '' } }

      it 'does not create an api key' do
        expect { create_key }.not_to change(Spree::ApiKey, :count)
      end

      it 'renders the new template' do
        create_key

        expect(response).to render_template(:new)
      end
    end
  end

  describe 'GET #edit' do
    subject(:edit) { get :edit, params: { id: api_key.to_param } }

    let(:api_key) { create(:api_key, store: store) }

    it 'renders the edit template' do
      edit

      expect(response).to render_template(:edit)
    end

    it 'assigns the api key' do
      edit

      expect(assigns[:api_key]).to eq(api_key)
    end
  end

  describe 'PUT #update' do
    subject(:update_key) { put :update, params: { id: api_key.to_param, api_key: key_params } }

    let!(:api_key) { create(:api_key, store: store, name: 'Old Name') }

    let(:key_params) do
      {
        name: 'New Name'
      }
    end

    it 'updates the api key' do
      update_key

      api_key.reload
      expect(api_key.name).to eq('New Name')
    end

    it 'redirects to show page' do
      update_key

      expect(response).to redirect_to(spree.admin_api_key_path(api_key))
    end

    context 'with invalid params' do
      let(:key_params) { { name: '' } }

      it 'does not update the api key' do
        update_key

        api_key.reload
        expect(api_key.name).to eq('Old Name')
      end

      it 'renders the edit template' do
        update_key

        expect(response).to render_template(:edit)
      end
    end

    context 'when trying to change key_type' do
      let!(:api_key) { create(:api_key, :publishable, store: store, name: 'Old Name') }
      let(:key_params) { { key_type: 'secret' } }

      it 'does not change the key type (key_type is not in permitted attributes)' do
        update_key

        api_key.reload
        expect(api_key.key_type).to eq('publishable')
      end
    end
  end

  # NOTE: destroy action is disabled via routes (except: :destroy)
  # The revoke action should be used instead to deactivate API keys

  describe 'PUT #revoke' do
    subject(:revoke_key) { put :revoke, params: { id: api_key.to_param } }

    let!(:api_key) { create(:api_key, store: store) }

    it 'revokes the api key' do
      expect(api_key.active?).to be true

      revoke_key

      api_key.reload
      expect(api_key.active?).to be false
      expect(api_key.revoked_at).to be_present
    end

    it 'redirects to show page' do
      revoke_key

      expect(response).to redirect_to(spree.admin_api_key_path(api_key))
    end

    it 'sets the flash message' do
      revoke_key

      expect(flash[:success]).to be_present
    end
  end
end
