# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Cancellation Reasons API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:reason) { create(:order_cancellation_reason, store: store, name: 'Out of stock') }

  path '/api/v3/admin/order_cancellation_reasons' do
    get 'List order cancellation reasons' do
      tags 'Reasons'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Why an order was called off before it shipped. Staff pick one when canceling.

        The vocabulary is the merchant's own — seeded with a starting set and
        edited from the dashboard. Inactive rows stay for the records that
        already reference them, but are not offered on new ones.
      DESC
      admin_scope :read, :settings

      admin_sdk_example 'order-cancellation-reasons/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name (contains)'
      parameter name: :'q[active_eq]', in: :query, type: :boolean, required: false,
                description: 'Filter by active flag'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort by field. Prefix with `-` for descending (e.g., `-created_at`).'

      response '200', 'order cancellation reasons found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].map { |r| r['id'] }).to include(reason.prefixed_id)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a order cancellation reason' do
      tags 'Reasons'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Adds a order cancellation reason to this store. Names are unique per store, ignoring case.'
      admin_scope :write, :settings

      admin_sdk_example 'order-cancellation-reasons/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[name],
        properties: {
          name: { type: :string, example: 'Out of stock' },
          active: { type: :boolean, example: true, description: 'Inactive reasons are hidden from the pickers on new records.' }
        }
      }

      response '201', 'order cancellation reason created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'A new reason' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('A new reason')
          expect(data['active']).to be(true)
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/order_cancellation_reasons/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Order cancellation reason ID'

    get 'Get a order cancellation reason' do
      tags 'Reasons'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single order cancellation reason by prefixed ID.'
      admin_scope :read, :settings

      admin_sdk_example 'order-cancellation-reasons/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'order cancellation reason found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { reason.prefixed_id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(reason.prefixed_id)
          expect(data['name']).to eq('Out of stock')
        end
      end

      response '404', 'order cancellation reason not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'ocr_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a order cancellation reason' do
      tags 'Reasons'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Renames a order cancellation reason or retires it. Deactivating keeps it on the records
        that already carry it while removing it from the pickers.
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'order-cancellation-reasons/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          active: { type: :boolean }
        }
      }

      response '200', 'order cancellation reason updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { reason.prefixed_id }
        let(:body) { { active: false } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['active']).to be(false)
        end
      end
    end

    delete 'Delete a order cancellation reason' do
      tags 'Reasons'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Removes a order cancellation reason the store no longer uses. A reason already recorded
        on a document is refused — deactivate it instead, so the history it
        explains stays readable.
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'order-cancellation-reasons/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '204', 'order cancellation reason deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { reason.prefixed_id }

        run_test!
      end
    end
  end
end
