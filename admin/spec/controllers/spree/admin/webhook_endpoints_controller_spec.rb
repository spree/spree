# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Admin::WebhookEndpointsController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }

  describe 'GET #index' do
    subject(:index) { get :index }

    let!(:webhook_endpoints) { create_list(:webhook_endpoint, 3, store: store) }
    let!(:other_store_endpoints) { create_list(:webhook_endpoint, 2, store: create(:store)) }

    it 'renders the index template' do
      index

      expect(response).to render_template(:index)
    end

    it 'assigns webhook endpoints for current store only' do
      index

      expect(assigns[:collection]).to contain_exactly(*webhook_endpoints)
    end
  end

  describe 'GET #show' do
    subject(:show) { get :show, params: { id: webhook_endpoint.id } }

    let(:webhook_endpoint) { create(:webhook_endpoint, store: store) }

    it 'renders the show template' do
      show

      expect(response).to render_template(:show)
    end

    it 'assigns the webhook endpoint' do
      show

      expect(assigns[:webhook_endpoint]).to eq(webhook_endpoint)
    end
  end

  describe 'GET #new' do
    subject(:new_action) { get :new }

    it 'renders the new template' do
      new_action

      expect(response).to render_template(:new)
    end

    it 'assigns a new webhook endpoint' do
      new_action

      expect(assigns[:webhook_endpoint]).to be_a_new(Spree::WebhookEndpoint)
    end
  end

  describe 'POST #create' do
    subject(:create_endpoint) { post :create, params: { webhook_endpoint: endpoint_params } }

    let(:endpoint_params) do
      {
        url: 'https://example.com/webhooks/receiver',
        active: true,
        subscriptions: %w[order.created order.completed]
      }
    end

    it 'creates a new webhook endpoint' do
      expect { create_endpoint }.to change(Spree::WebhookEndpoint, :count).by(1)
    end

    it 'sets the attributes correctly' do
      create_endpoint

      endpoint = Spree::WebhookEndpoint.last
      expect(endpoint.url).to eq('https://example.com/webhooks/receiver')
      expect(endpoint.active).to be true
      expect(endpoint.subscriptions).to eq(%w[order.created order.completed])
      expect(endpoint.store).to eq(store)
    end

    it 'generates a secret key' do
      create_endpoint

      endpoint = Spree::WebhookEndpoint.last
      expect(endpoint.secret_key).to be_present
    end

    it 'redirects to show page' do
      create_endpoint

      expect(response).to redirect_to(spree.admin_webhook_endpoint_path(Spree::WebhookEndpoint.last))
    end

    context 'with invalid params' do
      let(:endpoint_params) { { url: '' } }

      it 'does not create a webhook endpoint' do
        expect { create_endpoint }.not_to change(Spree::WebhookEndpoint, :count)
      end

      it 'renders the new template' do
        create_endpoint

        expect(response).to render_template(:new)
      end
    end

    context 'with all events subscription' do
      let(:endpoint_params) do
        {
          url: 'https://example.com/webhooks/all',
          active: true,
          subscriptions: ['*']
        }
      end

      it 'creates endpoint subscribed to all events' do
        create_endpoint

        endpoint = Spree::WebhookEndpoint.last
        expect(endpoint.subscriptions).to eq(['*'])
        expect(endpoint.subscribed_to?('order.created')).to be true
        expect(endpoint.subscribed_to?('product.updated')).to be true
      end
    end
  end

  describe 'GET #edit' do
    subject(:edit) { get :edit, params: { id: webhook_endpoint.id } }

    let(:webhook_endpoint) { create(:webhook_endpoint, store: store) }

    it 'renders the edit template' do
      edit

      expect(response).to render_template(:edit)
    end

    it 'assigns the webhook endpoint' do
      edit

      expect(assigns[:webhook_endpoint]).to eq(webhook_endpoint)
    end
  end

  describe 'PUT #update' do
    subject(:update_endpoint) { put :update, params: { id: webhook_endpoint.id, webhook_endpoint: endpoint_params } }

    let!(:webhook_endpoint) { create(:webhook_endpoint, store: store, url: 'https://old.example.com/webhook', active: true) }

    let(:endpoint_params) do
      {
        url: 'https://new.example.com/webhook',
        active: false,
        subscriptions: %w[product.created product.updated]
      }
    end

    it 'updates the webhook endpoint' do
      update_endpoint

      webhook_endpoint.reload
      expect(webhook_endpoint.url).to eq('https://new.example.com/webhook')
      expect(webhook_endpoint.active).to be false
      expect(webhook_endpoint.subscriptions).to eq(%w[product.created product.updated])
    end

    it 'redirects to show page' do
      update_endpoint

      expect(response).to redirect_to(spree.admin_webhook_endpoint_path(webhook_endpoint))
    end

    context 'with invalid params' do
      let(:endpoint_params) { { url: 'invalid-url' } }

      it 'does not update the webhook endpoint' do
        update_endpoint

        webhook_endpoint.reload
        expect(webhook_endpoint.url).to eq('https://old.example.com/webhook')
      end

      it 'renders the edit template' do
        update_endpoint

        expect(response).to render_template(:edit)
      end
    end

    context 'when deactivating endpoint' do
      let(:endpoint_params) { { active: false } }

      it 'marks the endpoint as inactive' do
        update_endpoint

        webhook_endpoint.reload
        expect(webhook_endpoint.active).to be false
      end
    end
  end

  describe 'DELETE #destroy' do
    subject(:destroy_endpoint) { delete :destroy, params: { id: webhook_endpoint.id } }

    let!(:webhook_endpoint) { create(:webhook_endpoint, store: store) }

    it 'soft deletes the webhook endpoint' do
      destroy_endpoint

      expect(webhook_endpoint.reload.deleted_at).not_to be_nil
    end

    it 'redirects to index' do
      destroy_endpoint

      expect(response).to redirect_to(spree.admin_webhook_endpoints_path)
    end
  end
end
