require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::WebhookEndpointsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  let!(:endpoint) do
    create(:webhook_endpoint, :with_subscriptions, store: store, name: 'Test endpoint')
  end

  describe 'GET #index' do
    subject { get :index, as: :json }

    it 'returns the store webhook endpoints' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |e| e['id'] }).to include(endpoint.prefixed_id)
    end

    it 'never exposes the secret_key on list responses' do
      subject
      list_entry = json_response['data'].find { |e| e['id'] == endpoint.prefixed_id }
      expect(list_entry['secret_key']).to be_nil
    end
  end

  describe 'GET #show' do
    subject { get :show, params: { id: endpoint.prefixed_id }, as: :json }

    it 'returns the endpoint with subscriptions' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Test endpoint')
      expect(json_response['subscriptions']).to eq(%w[order.created order.completed product.created])
    end

    context 'with a mix of successful and failed deliveries' do
      before do
        create(:webhook_delivery, :successful, webhook_endpoint: endpoint)
        create(:webhook_delivery, :successful, webhook_endpoint: endpoint)
        create(:webhook_delivery, :failed,     webhook_endpoint: endpoint)
      end

      it 'returns the lifetime delivery counters used by the health summary' do
        subject
        expect(json_response['total_delivery_count']).to eq(3)
        expect(json_response['successful_delivery_count']).to eq(2)
        expect(json_response['failed_delivery_count']).to eq(1)
      end
    end
  end

  describe 'POST #create' do
    subject { post :create, params: params, as: :json }

    let(:params) do
      {
        name: 'Order webhooks',
        url: 'https://example.com/hook',
        active: true,
        subscriptions: %w[order.created order.completed]
      }
    end

    it 'creates the endpoint and returns the plaintext secret_key exactly once' do
      expect { subject }.to change(Spree::WebhookEndpoint, :count).by(1)
      expect(response).to have_http_status(:created)
      created = Spree::WebhookEndpoint.last
      expect(json_response['id']).to eq(created.prefixed_id)
      expect(json_response['secret_key']).to be_present
      expect(json_response['secret_key']).to eq(created.secret_key)
    end

    context 'when the url is invalid' do
      let(:params) { { url: 'not-a-url', subscriptions: [] } }

      it 'returns a validation error' do
        subject
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
      end
    end
  end

  describe 'PATCH #update' do
    subject { patch :update, params: { id: endpoint.prefixed_id, **params }, as: :json }

    let(:params) { { name: 'Renamed', active: false } }

    it 'updates editable attributes' do
      subject
      expect(response).to have_http_status(:ok)
      endpoint.reload
      expect(endpoint.name).to eq('Renamed')
      expect(endpoint.active).to eq(false)
    end

    it 'does not return the secret_key on subsequent reads' do
      subject
      expect(json_response['secret_key']).to be_nil
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, params: { id: endpoint.prefixed_id }, as: :json }

    it 'soft-deletes the endpoint' do
      subject
      expect(response).to have_http_status(:no_content)
      expect(endpoint.reload.deleted_at).to be_present
    end
  end

  describe 'PATCH #disable / #enable' do
    it 'flips the endpoint inactive and back' do
      patch :disable, params: { id: endpoint.prefixed_id }, as: :json
      expect(response).to have_http_status(:ok)
      expect(endpoint.reload.active).to eq(false)
      expect(endpoint.disabled_at).to be_present

      patch :enable, params: { id: endpoint.prefixed_id }, as: :json
      expect(response).to have_http_status(:ok)
      expect(endpoint.reload.active).to eq(true)
      expect(endpoint.disabled_at).to be_nil
    end
  end

  describe 'POST #send_test' do
    subject { post :send_test, params: { id: endpoint.prefixed_id }, as: :json }

    it 'creates a webhook.test delivery and returns it' do
      expect { subject }.to change { endpoint.webhook_deliveries.count }.by(1)
      expect(response).to have_http_status(:created)
      expect(json_response['event_name']).to eq('webhook.test')
    end
  end
end
