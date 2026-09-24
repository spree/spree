require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::WebhookDeliveriesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  let(:endpoint) { create(:webhook_endpoint, store: store) }
  let!(:successful_delivery) { create(:webhook_delivery, :successful, webhook_endpoint: endpoint) }
  let!(:failed_delivery)     { create(:webhook_delivery, :failed,     webhook_endpoint: endpoint) }

  describe 'GET #index' do
    subject { get :index, params: { webhook_endpoint_id: endpoint.prefixed_id }, as: :json }

    it 'returns the deliveries scoped to the endpoint, most-recent-first' do
      subject
      expect(response).to have_http_status(:ok)
      ids = json_response['data'].map { |d| d['id'] }
      expect(ids).to contain_exactly(successful_delivery.prefixed_id, failed_delivery.prefixed_id)
      # `recent` scope orders by created_at DESC; the later-built failed delivery
      # is created last, so it comes first.
      expect(ids.first).to eq(failed_delivery.prefixed_id)
    end

    it 'does not leak deliveries from other endpoints' do
      other = create(:webhook_endpoint, store: store)
      create(:webhook_delivery, :successful, webhook_endpoint: other)

      subject
      expect(json_response['data'].size).to eq(2)
    end
  end

  describe 'GET #show' do
    subject do
      get :show,
          params: { webhook_endpoint_id: endpoint.prefixed_id, id: failed_delivery.prefixed_id },
          as: :json
    end

    it 'returns the delivery with payload, response code, and webhook_endpoint_id' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['response_code']).to eq(500)
      expect(json_response['success']).to eq(false)
      expect(json_response['webhook_endpoint_id']).to eq(endpoint.prefixed_id)
      expect(json_response['payload']).to be_present
    end

    # Rows written before payment session keys joined the redaction list still
    # hold live gateway credentials, so the read path redacts them again.
    context 'when a stored payload holds payment session credentials' do
      before do
        failed_delivery.update_columns(
          payload: {
            'name' => 'payment_session.created',
            'data' => {
              'external_client_secret' => 'seti_live_secret',
              'external_data' => {
                'client_secret' => 'pi_live_secret',
                'ephemeral_key_secret' => 'ek_live_secret'
              }
            }
          }
        )
      end

      it 'does not return them, at any depth' do
        subject

        data = json_response['payload']['data']
        expect(data['external_client_secret']).to eq(Spree::WebhookPayloadRedaction::REDACTION_PLACEHOLDER)
        expect(data['external_data']['client_secret']).to eq(Spree::WebhookPayloadRedaction::REDACTION_PLACEHOLDER)
        expect(data['external_data']['ephemeral_key_secret']).to eq(Spree::WebhookPayloadRedaction::REDACTION_PLACEHOLDER)
        expect(response.body).not_to include('pi_live_secret', 'ek_live_secret', 'seti_live_secret')
      end
    end
  end

  # The payload is the record the event is about; the webhooks permission
  # alone does not grant reading orders or customers.
  describe 'payload visibility' do
    subject do
      get :show,
          params: { webhook_endpoint_id: endpoint.prefixed_id, id: failed_delivery.prefixed_id },
          as: :json
    end

    let(:headers) { { 'x-spree-api-key' => caller_key.plaintext_token } }

    context 'with only the webhooks permission' do
      let(:caller_key) { create(:api_key, :secret, store: store, scopes: %w[read_webhooks]) }

      it 'withholds an order event payload but keeps the delivery details' do
        subject

        expect(response).to have_http_status(:ok)
        expect(json_response['payload']).to be_nil
        expect(json_response['response_code']).to eq(500)
      end

      it 'shows the payload of a test delivery' do
        failed_delivery.update_columns(event_name: 'webhook.test')

        subject

        expect(json_response['payload']).to be_present
      end
    end

    context 'with permission to read orders too' do
      let(:caller_key) { create(:api_key, :secret, store: store, scopes: %w[read_webhooks read_orders]) }

      it 'shows the payload' do
        subject

        expect(json_response['payload']).to be_present
      end
    end

    # Rows written before these keys joined the redaction list still hold
    # them, so the read path redacts them again.
    context 'when a stored payload holds a cart token and a gift card code' do
      let(:caller_key) { create(:api_key, :secret, store: store, scopes: %w[read_webhooks read_orders]) }

      before do
        failed_delivery.update_columns(
          payload: {
            'name' => 'order.completed',
            'data' => { 'token' => 'guest-token', 'gift_card' => { 'code' => 'SPEND-ME' } }
          }
        )
      end

      it 'does not return them' do
        subject

        expect(response.body).not_to include('guest-token', 'SPEND-ME')
      end
    end
  end

  describe 'POST #redeliver' do
    subject do
      post :redeliver,
           params: { webhook_endpoint_id: endpoint.prefixed_id, id: failed_delivery.prefixed_id },
           as: :json
    end

    before do
      allow_any_instance_of(Spree::WebhookDelivery).to receive(:queue_for_delivery!)
    end

    it 'creates a new delivery row with the same payload + event_name' do
      expect { subject }.to change { endpoint.webhook_deliveries.count }.by(1)
      expect(response).to have_http_status(:created)
      new_id = json_response['id']
      new_delivery = Spree::WebhookDelivery.find_by_prefix_id!(new_id)
      expect(new_delivery.payload).to eq(failed_delivery.payload)
      expect(new_delivery.event_name).to eq(failed_delivery.event_name)
    end
  end
end
