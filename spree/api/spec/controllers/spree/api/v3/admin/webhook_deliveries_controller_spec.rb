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
