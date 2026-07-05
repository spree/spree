# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Webhook Deliveries API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:webhook_endpoint) do
    create(:webhook_endpoint, store: store, name: 'Order pipeline', url: 'https://shop.example.com/webhooks')
  end
  let!(:successful_delivery) { create(:webhook_delivery, :successful, webhook_endpoint: webhook_endpoint) }
  let!(:failed_delivery)     { create(:webhook_delivery, :failed,     webhook_endpoint: webhook_endpoint) }

  path '/api/v3/admin/webhook_endpoints/{webhook_endpoint_id}/deliveries' do
    parameter name: :webhook_endpoint_id, in: :path, type: :string, required: true,
              description: 'Parent webhook endpoint ID'

    get 'List webhook deliveries' do
      tags 'Webhooks'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns delivery attempts for the given endpoint, most recent first.
        Each row carries the original request payload, the response code
        (when the receiver replied), the execution time, and any transport
        error — everything needed to audit failures and decide whether to
        redeliver.
      DESC
      admin_scope :read, :webhooks

      admin_sdk_example 'webhook-endpoints/deliveries/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[event_name_eq]', in: :query, type: :string, required: false,
                description: 'Filter by event name (exact)'
      parameter name: :'q[success_eq]', in: :query, type: :boolean, required: false,
                description: 'Filter by success flag'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort by field. Prefix with `-` for descending (e.g., `-delivered_at`).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'deliveries found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:webhook_endpoint_id) { webhook_endpoint.prefixed_id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          ids = data['data'].map { |d| d['id'] }
          expect(ids).to include(successful_delivery.prefixed_id, failed_delivery.prefixed_id)
        end
      end

      response '404', 'parent webhook endpoint not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:webhook_endpoint_id) { 'whe_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/webhook_endpoints/{webhook_endpoint_id}/deliveries/{id}' do
    parameter name: :webhook_endpoint_id, in: :path, type: :string, required: true,
              description: 'Parent webhook endpoint ID'
    parameter name: :id, in: :path, type: :string, required: true, description: 'Webhook delivery ID'

    get 'Get a webhook delivery' do
      tags 'Webhooks'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns a single delivery attempt with the full request payload and
        the response body the receiver returned. Use this for ad-hoc debug
        of failed deliveries.
      DESC
      admin_scope :read, :webhooks

      admin_sdk_example 'webhook-endpoints/deliveries/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'delivery found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:webhook_endpoint_id) { webhook_endpoint.prefixed_id }
        let(:id) { failed_delivery.prefixed_id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(failed_delivery.prefixed_id)
          expect(data['success']).to eq(false)
          expect(data['response_code']).to eq(500)
          expect(data['webhook_endpoint_id']).to eq(webhook_endpoint.prefixed_id)
          expect(data['payload']).to be_present
        end
      end

      response '404', 'delivery not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:webhook_endpoint_id) { webhook_endpoint.prefixed_id }
        let(:id) { 'whd_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/webhook_endpoints/{webhook_endpoint_id}/deliveries/{id}/redeliver' do
    parameter name: :webhook_endpoint_id, in: :path, type: :string, required: true,
              description: 'Parent webhook endpoint ID'
    parameter name: :id, in: :path, type: :string, required: true,
              description: 'Webhook delivery ID to redeliver'

    post 'Redeliver a webhook delivery' do
      tags 'Webhooks'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Creates a new delivery row with the same payload + event_name and
        queues it. The original row is preserved for audit history.
      DESC
      admin_scope :write, :webhooks

      admin_sdk_example 'webhook-endpoints/deliveries/redeliver'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '201', 'redelivery queued' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:webhook_endpoint_id) { webhook_endpoint.prefixed_id }
        let(:id) { failed_delivery.prefixed_id }

        before do
          allow_any_instance_of(Spree::WebhookDelivery).to receive(:queue_for_delivery!)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).not_to eq(failed_delivery.prefixed_id)
          expect(data['event_name']).to eq(failed_delivery.event_name)
        end
      end
    end
  end
end
