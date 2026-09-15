# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Store Credits API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:customer) { create(:user) }
  let!(:store_credit) { create(:store_credit, store: store, customer: customer, amount: 50, currency: 'USD') }

  path '/api/v3/admin/store_credits' do
    get 'List store credits' do
      tags 'Store Credits'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns every store credit in the current store, across all customers.
        Read-only: issuing, editing and deleting a credit stays nested under
        the customer that holds it.

        `meta.totals` carries the outstanding balance as one row per currency,
        summed over the same filter this request used — so filtering by a
        customer answers that customer's balance and no filter answers the
        store's liability.
      DESC
      admin_scope :read, :store_credits

      admin_sdk_example 'store-credits/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[customer_id_eq]', in: :query, type: :string, required: false,
                description: 'Filter by the customer holding the credit'
      parameter name: :'q[customer_email_cont]', in: :query, type: :string, required: false,
                description: 'Filter by customer email (contains)'
      parameter name: :'q[currency_eq]', in: :query, type: :string, required: false,
                description: 'Filter by currency'
      parameter name: :'q[memo_cont]', in: :query, type: :string, required: false,
                description: 'Filter by the free-text reason (contains)'
      parameter name: :'q[outstanding]', in: :query, type: :boolean, required: false,
                description: 'True for credits with money left, false for credits already spent'
      parameter name: :'q[from_gift_card]', in: :query, type: :boolean, required: false,
                description: 'True for credits a gift card redemption created, false for every other origin'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (customer, created_by).'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort by field. Prefix with `-` for descending (e.g., `-created_at`).'

      response '200', 'store credits found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('StoreCredit')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(store_credit.prefixed_id)
          expect(data['meta']['totals'].first['currency']).to eq('USD')
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/store_credits/{id}' do
    parameter name: :id, in: :path, type: :string, required: true

    get 'Retrieve a store credit' do
      tags 'Store Credits'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :store_credits

      admin_sdk_example 'store-credits/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (customer, created_by).'

      response '200', 'store credit found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { store_credit.prefixed_id }

        schema '$ref' => '#/components/schemas/StoreCredit'

        run_test! do |response|
          expect(JSON.parse(response.body)['id']).to eq(store_credit.prefixed_id)
        end
      end

      response '404', 'not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'credit_missing' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/store_credits/{store_credit_id}/events' do
    parameter name: :store_credit_id, in: :path, type: :string, required: true

    get "List a store credit's ledger" do
      tags 'Store Credits'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Every movement of the credit's balance, newest first: allocated when
        issued, authorized when a checkout starts against it, captured when
        that order is paid, and voided or credited back if it is cancelled.
      DESC
      admin_scope :read, :store_credits

      admin_sdk_example 'store-credit-events/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'

      response '200', 'events found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:store_credit_id) { store_credit.prefixed_id }

        schema SwaggerSchemaHelpers.paginated('StoreCreditEvent')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('action')).to include('allocation')
        end
      end
    end
  end
end
