# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Webhook Endpoints API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:webhook_endpoint) do
    create(
      :webhook_endpoint,
      :with_subscriptions,
      store: store,
      name: 'Order pipeline',
      url: 'https://shop.example.com/webhooks/orders'
    )
  end

  path '/api/v3/admin/webhook_endpoints' do
    get 'List webhook endpoints' do
      tags 'Webhooks'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns outbound webhook subscriptions for the current store. Each
        endpoint receives a signed POST when any subscribed event fires.
        `secret_key` is `null` on list reads — the plaintext is delivered
        exactly once on create.
      DESC
      admin_scope :read, :settings

      admin_sdk_example 'webhook-endpoints/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name (contains)'
      parameter name: :'q[url_cont]', in: :query, type: :string, required: false,
                description: 'Filter by URL (contains)'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort by field. Prefix with `-` for descending (e.g., `-created_at`).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'webhook endpoints found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].map { |e| e['id'] }).to include(webhook_endpoint.prefixed_id)

          # `secret_key` is the encrypted signing secret — never returned
          # outside the one-shot create response.
          data['data'].each do |endpoint|
            expect(endpoint['secret_key']).to be_nil
          end
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a webhook endpoint' do
      tags 'Webhooks'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Creates a new outbound webhook subscription. The plaintext
        `secret_key` is returned **once** in this response — persist it
        immediately to verify incoming webhook signatures. Subsequent reads
        return `null` for the secret. Pass an empty `subscriptions` array or
        omit it to receive every event.
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'webhook-endpoints/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[url],
        properties: {
          name: { type: :string, example: 'Order pipeline' },
          url: { type: :string, example: 'https://example.com/webhooks/orders' },
          active: { type: :boolean, example: true },
          subscriptions: {
            type: :array,
            items: { type: :string },
            example: %w[order.completed order.canceled]
          }
        }
      }

      response '201', 'webhook endpoint created — secret_key returned once' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          {
            name: 'CI integration',
            url: 'https://ci.example.com/webhooks',
            subscriptions: ['order.completed']
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('CI integration')
          expect(data['url']).to eq('https://ci.example.com/webhooks')
          expect(data['subscriptions']).to eq(['order.completed'])
          expect(data['secret_key']).to be_present
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { url: 'not a url' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/webhook_endpoints/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Webhook endpoint ID'

    get 'Get a webhook endpoint' do
      tags 'Webhooks'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single webhook endpoint by prefixed ID.'
      admin_scope :read, :settings

      admin_sdk_example 'webhook-endpoints/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'webhook endpoint found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { webhook_endpoint.prefixed_id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(webhook_endpoint.prefixed_id)
          expect(data['name']).to eq('Order pipeline')
          expect(data['secret_key']).to be_nil
          expect(data).to include(
            'total_delivery_count',
            'successful_delivery_count',
            'failed_delivery_count'
          )
        end
      end

      response '404', 'webhook endpoint not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'whe_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a webhook endpoint' do
      tags 'Webhooks'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Updates name, URL, active flag, or the event subscription list.
        Toggling `active` here is equivalent to calling `disable`/`enable`
        without an audit reason.
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'webhook-endpoints/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          url: { type: :string },
          active: { type: :boolean },
          subscriptions: { type: :array, items: { type: :string } }
        }
      }

      response '200', 'webhook endpoint updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { webhook_endpoint.prefixed_id }
        let(:body) { { name: 'Order pipeline (renamed)' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Order pipeline (renamed)')
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { webhook_endpoint.prefixed_id }
        let(:body) { { url: 'not a url' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    delete 'Delete a webhook endpoint' do
      tags 'Webhooks'
      security [api_key: [], bearer_auth: []]
      description 'Soft-deletes the endpoint and stops future deliveries.'
      admin_scope :write, :settings

      admin_sdk_example 'webhook-endpoints/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '204', 'webhook endpoint deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { webhook_endpoint.prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/admin/webhook_endpoints/{id}/send_test' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Webhook endpoint ID'

    post 'Send a test delivery' do
      tags 'Webhooks'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Creates a `webhook.test` delivery record and queues it. Use this to
        verify the endpoint is reachable and your signature verification
        accepts Spree's payloads.
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'webhook-endpoints/send-test'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '201', 'test delivery queued' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { webhook_endpoint.prefixed_id }

        before do
          # The model enqueues a background job — stub it so the request spec
          # doesn't need an active queue adapter.
          allow_any_instance_of(Spree::WebhookDelivery).to receive(:queue_for_delivery!)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['event_name']).to eq('webhook.test')
          expect(data['webhook_endpoint_id']).to eq(webhook_endpoint.prefixed_id)
        end
      end
    end
  end

  path '/api/v3/admin/webhook_endpoints/{id}/enable' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Webhook endpoint ID'

    patch 'Re-enable a webhook endpoint' do
      tags 'Webhooks'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Re-enables an endpoint that was manually or automatically disabled.'
      admin_scope :write, :settings

      admin_sdk_example 'webhook-endpoints/enable'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'webhook endpoint enabled' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { webhook_endpoint.prefixed_id }

        before { webhook_endpoint.update!(active: false, disabled_at: Time.current, disabled_reason: 'Failed') }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['active']).to eq(true)
          expect(data['disabled_at']).to be_nil
        end
      end
    end
  end

  path '/api/v3/admin/webhook_endpoints/{id}/disable' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Webhook endpoint ID'

    patch 'Disable a webhook endpoint' do
      tags 'Webhooks'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Manually pauses an endpoint. Unlike auto-disable (triggered after
        repeated delivery failures), no notification email is sent.
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'webhook-endpoints/disable'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          reason: { type: :string, example: 'Investigating elevated 5xx rate' }
        }
      }

      response '200', 'webhook endpoint disabled' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { webhook_endpoint.prefixed_id }
        let(:body) { { reason: 'Investigating' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['active']).to eq(false)
          expect(data['disabled_at']).to be_present
          expect(data['disabled_reason']).to eq('Investigating')
        end
      end
    end
  end
end
