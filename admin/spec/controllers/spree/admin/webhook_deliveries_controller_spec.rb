# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Admin::WebhookDeliveriesController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:webhook_endpoint) { create(:webhook_endpoint, store: store) }

  describe 'GET #index' do
    subject(:index) { get :index, params: { webhook_endpoint_id: webhook_endpoint.to_param } }

    let!(:deliveries) { create_list(:webhook_delivery, 3, webhook_endpoint: webhook_endpoint) }
    let!(:other_endpoint_deliveries) { create_list(:webhook_delivery, 2) }

    it 'renders the index template' do
      index

      expect(response).to render_template(:index)
    end

    it 'assigns deliveries for the webhook endpoint only' do
      index

      expect(assigns[:collection]).to contain_exactly(*deliveries)
    end

    it 'assigns the parent webhook endpoint' do
      index

      expect(assigns[:webhook_endpoint]).to eq(webhook_endpoint)
    end

    context 'with mixed delivery statuses' do
      let!(:successful_delivery) { create(:webhook_delivery, :successful, webhook_endpoint: webhook_endpoint) }
      let!(:failed_delivery) { create(:webhook_delivery, :failed, webhook_endpoint: webhook_endpoint) }
      let!(:pending_delivery) { create(:webhook_delivery, :pending, webhook_endpoint: webhook_endpoint) }

      it 'includes all delivery statuses' do
        index

        expect(assigns[:collection]).to include(successful_delivery, failed_delivery, pending_delivery)
      end
    end

    context 'ordering' do
      # Use a separate endpoint to avoid conflicts with deliveries from outer context
      let(:ordering_endpoint) { create(:webhook_endpoint, store: store) }
      let!(:old_delivery) { create(:webhook_delivery, webhook_endpoint: ordering_endpoint, created_at: 2.days.ago) }
      let!(:new_delivery) { create(:webhook_delivery, webhook_endpoint: ordering_endpoint, created_at: 1.hour.ago) }

      it 'orders deliveries by created_at descending' do
        get :index, params: { webhook_endpoint_id: ordering_endpoint.to_param }

        collection = assigns[:collection]
        expect(collection.first).to eq(new_delivery)
        expect(collection.last).to eq(old_delivery)
      end
    end
  end

  describe 'GET #show' do
    subject(:show) { get :show, params: { webhook_endpoint_id: webhook_endpoint.to_param, id: delivery.to_param } }

    let(:delivery) { create(:webhook_delivery, :successful, webhook_endpoint: webhook_endpoint) }

    it 'renders the show template' do
      show

      expect(response).to render_template(:show)
    end

    it 'assigns the webhook delivery' do
      show

      expect(assigns[:webhook_delivery]).to eq(delivery)
    end

    it 'assigns the parent webhook endpoint' do
      show

      expect(assigns[:webhook_endpoint]).to eq(webhook_endpoint)
    end

    context 'with successful delivery' do
      let(:delivery) do
        create(:webhook_delivery, :successful,
               webhook_endpoint: webhook_endpoint,
               response_code: 200,
               execution_time: 150,
               response_body: '{"status": "ok"}')
      end

      it 'shows delivery details' do
        show

        expect(response.body).to include('200')
      end
    end

    context 'with failed delivery' do
      let(:delivery) do
        create(:webhook_delivery, :failed,
               webhook_endpoint: webhook_endpoint,
               response_code: 500,
               request_errors: 'Internal Server Error')
      end

      it 'shows error information' do
        show

        expect(response.body).to include('500')
      end
    end

    context 'with timeout error' do
      let(:delivery) do
        create(:webhook_delivery, :timeout,
               webhook_endpoint: webhook_endpoint)
      end

      it 'shows timeout information' do
        show

        expect(assigns[:webhook_delivery].error_type).to eq('timeout')
      end
    end

    context 'with connection error' do
      let(:delivery) do
        create(:webhook_delivery, :connection_error,
               webhook_endpoint: webhook_endpoint)
      end

      it 'shows connection error information' do
        show

        expect(assigns[:webhook_delivery].error_type).to eq('connection_error')
      end
    end
  end
end
