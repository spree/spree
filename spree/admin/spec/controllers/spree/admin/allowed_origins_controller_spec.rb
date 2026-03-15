# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Admin::AllowedOriginsController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }

  describe 'GET #index' do
    subject(:index) { get :index }

    let!(:allowed_origins) { create_list(:allowed_origin, 3, store: store) }
    let!(:other_store_origins) { create_list(:allowed_origin, 2, store: create(:store)) }

    it 'renders the index template' do
      index

      expect(response).to render_template(:index)
    end

    it 'assigns allowed origins for current store only' do
      index

      expect(assigns[:collection]).to contain_exactly(*allowed_origins)
    end
  end

  describe 'GET #new' do
    subject(:new_action) { get :new }

    it 'renders the new template' do
      new_action

      expect(response).to render_template(:new)
    end

    it 'assigns a new allowed origin' do
      new_action

      expect(assigns[:allowed_origin]).to be_a_new(Spree::AllowedOrigin)
    end
  end

  describe 'POST #create' do
    subject(:create_origin) { post :create, params: { allowed_origin: origin_params } }

    let(:origin_params) do
      { origin: 'https://myshop.example.com' }
    end

    it 'creates a new allowed origin' do
      expect { create_origin }.to change(Spree::AllowedOrigin, :count).by(1)
    end

    it 'sets the attributes correctly' do
      create_origin

      allowed_origin = Spree::AllowedOrigin.last
      expect(allowed_origin.origin).to eq('https://myshop.example.com')
      expect(allowed_origin.store).to eq(store)
    end

    it 'redirects to index' do
      create_origin

      expect(response).to redirect_to(spree.admin_allowed_origins_path)
    end

    context 'with invalid params' do
      let(:origin_params) { { origin: '' } }

      it 'does not create an allowed origin' do
        expect { create_origin }.not_to change(Spree::AllowedOrigin, :count)
      end

      it 'renders the new template' do
        create_origin

        expect(response).to render_template(:new)
      end
    end
  end

  describe 'GET #edit' do
    subject(:edit) { get :edit, params: { id: allowed_origin.to_param } }

    let(:allowed_origin) { create(:allowed_origin, store: store) }

    it 'renders the edit template' do
      edit

      expect(response).to render_template(:edit)
    end

    it 'assigns the allowed origin' do
      edit

      expect(assigns[:allowed_origin]).to eq(allowed_origin)
    end
  end

  describe 'PATCH #update' do
    subject(:update_origin) { patch :update, params: { id: allowed_origin.to_param, allowed_origin: origin_params } }

    let!(:allowed_origin) { create(:allowed_origin, store: store, origin: 'https://old.example.com') }

    let(:origin_params) do
      { origin: 'https://new.example.com' }
    end

    it 'updates the allowed origin' do
      update_origin

      allowed_origin.reload
      expect(allowed_origin.origin).to eq('https://new.example.com')
    end

    it 'redirects to index' do
      update_origin

      expect(response).to redirect_to(spree.admin_allowed_origins_path)
    end

    context 'with invalid params' do
      let(:origin_params) { { origin: '' } }

      it 'does not update the allowed origin' do
        update_origin

        allowed_origin.reload
        expect(allowed_origin.origin).to eq('https://old.example.com')
      end

      it 'renders the edit template' do
        update_origin

        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'DELETE #destroy' do
    subject(:destroy_origin) { delete :destroy, params: { id: allowed_origin.to_param } }

    let!(:allowed_origin) { create(:allowed_origin, store: store) }

    it 'deletes the allowed origin' do
      expect { destroy_origin }.to change(Spree::AllowedOrigin, :count).by(-1)
    end

    it 'redirects to index' do
      destroy_origin

      expect(response).to redirect_to(spree.admin_allowed_origins_path)
    end
  end
end
