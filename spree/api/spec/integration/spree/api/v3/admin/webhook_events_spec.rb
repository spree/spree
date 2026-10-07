# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Webhook Events API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/webhook_events' do
    get 'List webhook events' do
      tags 'Webhooks'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns every event a webhook endpoint can subscribe to, including those installed ' \
                  'extensions declare. Credential events reach only endpoints that name them, and ' \
                  'subscribing to one needs the permission listed; deprecated events name their replacement.'

      admin_sdk_example 'webhook-events/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'events returned' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('name')).to include('order.placed', 'customer.password_reset_requested')
        end
      end
    end
  end
end
