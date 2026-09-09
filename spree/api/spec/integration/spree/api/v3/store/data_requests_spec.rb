# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Data Requests API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  path '/api/v3/store/customers/me/data_requests' do
    get 'List data requests' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the authenticated customer\'s GDPR data requests, most recent first'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :limit, in: :query, type: :integer, required: false

      response '200', 'data requests found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let!(:data_request) { create(:data_request, store: store, customer: user) }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/DataRequest' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].first).to include('id', 'kind', 'status')
        end
      end
    end

    post 'Open a data request' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Opens a GDPR request for a copy of the customer's personal data (`access`)
        or its erasure (`erasure`). The work happens in the background and the
        response is the pending request.

        An erasure request requires the account password. A request of the same
        kind that is still in flight is returned instead of starting a second one.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          kind: { type: :string, enum: %w[access erasure], description: 'Defaults to access' },
          current_password: { type: :string, description: 'Required for erasure' }
        }
      }

      response '202', 'request accepted' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { kind: 'access' } }

        schema '$ref' => '#/components/schemas/DataRequest'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['kind']).to eq('access')
          expect(data['status']).to eq('pending')
        end
      end

      response '422', 'erasure without the account password' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { kind: 'erasure' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/customers/me/data_requests/{id}' do
    get 'Get a data request' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns one of the customer\'s own data requests, with a download link once the export is ready'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'data request found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:data_request) { create(:data_request, store: store, customer: user) }
        let(:id) { data_request.prefixed_id }

        schema '$ref' => '#/components/schemas/DataRequest'

        run_test!
      end

      response '404', 'not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { 'dsr_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
