# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Customer Groups API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:customer_group) { create(:customer_group, store: store, name: 'VIPs', description: 'Top spenders') }
  let!(:other_group) { create(:customer_group, store: store, name: 'Wholesale') }

  path '/api/v3/admin/customer_groups' do
    get 'List customer groups' do
      tags 'Customer Groups'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns the customer groups configured for the current store. Groups
        segment customers for targeted promotions (see the `customer_group`
        promotion rule) and reporting. The list endpoint never embeds the
        member list — fetch a single group with `?expand=customers` if you
        need them inline, or query `/admin/customers?customer_group_id_in=…`
        for paginated membership.
      DESC
      admin_scope :read, :customers

      admin_sdk_example 'customer-groups/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name (contains)'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort by field. Prefix with `-` for descending (e.g., `-created_at`).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'customer groups found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('CustomerGroup')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          ids = data['data'].pluck('id')
          expect(ids).to include(customer_group.prefixed_id, other_group.prefixed_id)
          # Index payload never embeds customers, even for non-empty groups.
          expect(data['data'].first).not_to have_key('customers')
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a customer group' do
      tags 'Customer Groups'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Creates a customer group in the current store. `customer_ids` is
        optional; when present, customers are attached at create time.
        Pass prefixed IDs (e.g. `cus_…`) — the server decodes them
        automatically.
      DESC
      admin_scope :write, :customers

      admin_sdk_example 'customer-groups/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[name],
        properties: {
          name: { type: :string, example: 'Wholesale' },
          description: { type: :string, example: 'B2B accounts', nullable: true },
          customer_ids: { type: :array, items: { type: :string }, example: ['cus_UkLWZg9DAJ'] }
        }
      }

      response '201', 'customer group created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:alice) { create(:user) }
        let(:body) { { name: 'Wholesale 2', description: 'B2B accounts', customer_ids: [alice.prefixed_id] } }

        schema '$ref' => '#/components/schemas/CustomerGroup'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Wholesale 2')
          expect(data['description']).to eq('B2B accounts')
          expect(data['customers_count']).to eq(1)
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

  path '/api/v3/admin/customer_groups/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Customer group prefixed ID'

    get 'Get a customer group' do
      tags 'Customer Groups'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns a single customer group. Pass `?expand=customers` to embed
        the full member list inline (recommended only for single-record
        reads — embed cost scales with membership size).
      DESC
      admin_scope :read, :customers

      admin_sdk_example 'customer-groups/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to embed. Supported: `customers`.'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'customer group found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { customer_group.prefixed_id }

        schema '$ref' => '#/components/schemas/CustomerGroup'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(customer_group.prefixed_id)
          expect(data['name']).to eq('VIPs')
          expect(data['description']).to eq('Top spenders')
          expect(data).not_to have_key('customers')
        end
      end

      response '200', 'customer group with embedded customers' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { customer_group.prefixed_id }
        let(:expand) { 'customers' }
        let(:alice) { create(:user) }

        before { customer_group.customers << alice }

        schema '$ref' => '#/components/schemas/CustomerGroup'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['customers']).to be_an(Array)
          expect(data['customers'].pluck('id')).to include(alice.prefixed_id)
        end
      end

      response '404', 'customer group not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'cg_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a customer group' do
      tags 'Customer Groups'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Updates name, description, or membership. `customer_ids` is a
        full-set replacement — the server reconciles the membership to
        match the array, adding new IDs and removing ones not present.
        Send `customer_ids: []` to clear all members.
      DESC
      admin_scope :write, :customers

      admin_sdk_example 'customer-groups/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'VIP customers (Q1)' },
          description: { type: :string, example: 'Updated description', nullable: true },
          customer_ids: { type: :array, items: { type: :string }, example: ['cus_UkLWZg9DAJ'] }
        }
      }

      response '200', 'customer group updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { customer_group.prefixed_id }
        let(:body) { { name: 'VIP customers (Q1)' } }

        schema '$ref' => '#/components/schemas/CustomerGroup'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('VIP customers (Q1)')
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { customer_group.prefixed_id }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    delete 'Delete a customer group' do
      tags 'Customer Groups'
      security [api_key: [], bearer_auth: []]
      description 'Soft-deletes the group. Member users are not deleted; their `customer_group_users` rows are dropped.'
      admin_scope :write, :customers

      admin_sdk_example 'customer-groups/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'customer group deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { customer_group.prefixed_id }

        run_test!
      end
    end
  end
end
