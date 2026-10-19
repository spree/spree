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
      filter_parameters_for

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
        or its erasure (`erasure`). Nothing happens until the request is confirmed
        from the link emailed to the account's address: the response is the request
        awaiting confirmation, and the link opens `redirect_url` with the
        confirmation token appended. The work then happens in the background.

        An erasure request requires the account password. A request of the same
        kind that is still in flight is returned instead of starting a second one,
        and a request still awaiting confirmation sends the email again.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      request_body_for(required: false)

      response '202', 'request accepted' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { kind: 'access' } }

        schema '$ref' => '#/components/schemas/DataRequest'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['kind']).to eq('access')
          expect(data['status']).to eq('awaiting_confirmation')
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
      description 'Returns one of the customer\'s own data requests. The download link is never shown here: it goes only to the holder of the emailed confirmation token'

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

  path '/api/v3/store/data_requests/{token}' do
    get 'Get a data request by its confirmation token' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Returns the data request the emailed confirmation token belongs to, with a
        download link once the export is ready. Needs no signed-in session, because
        the link may be opened on a device that was never signed in.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :token, in: :path, type: :string, required: true

      response '200', 'data request found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:data_request) { create(:data_request, store: store, customer: user) }
        let(:token) { data_request.generate_token_for(:confirmation) }

        schema '$ref' => '#/components/schemas/DataRequest'

        run_test!
      end

      response '404', 'token not recognised' do
        let(:'x-spree-api-key') { api_key.token }
        let(:token) { 'not-a-token' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/data_requests/{token}/confirmation' do
    post 'Confirm a data request' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Confirms a data request with the token from the confirmation email, and
        starts the work. Call it when the person presses a button on the page the
        link opens, never when the page loads: some mail scanners open links and
        run the page's scripts. Confirming again returns the request as it stands.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :token, in: :path, type: :string, required: true

      response '200', 'data request confirmed' do
        let(:'x-spree-api-key') { api_key.token }
        let(:data_request) { create(:data_request, :awaiting_confirmation, store: store, customer: user) }
        let(:token) { data_request.generate_token_for(:confirmation) }

        schema '$ref' => '#/components/schemas/DataRequest'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('pending')
        end
      end

      response '422', 'token not recognised, or the request has lapsed' do
        let(:'x-spree-api-key') { api_key.token }
        let(:token) { 'not-a-token' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
