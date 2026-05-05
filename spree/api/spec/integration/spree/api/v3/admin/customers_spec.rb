# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Customers API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:customer) { create(:user, email: 'jane@example.com', first_name: 'Jane', last_name: 'Doe') }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/customers' do
    get 'List customers' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a paginated list of customers. Supports Ransack search/filters.'
      admin_scope :read, :customers

      admin_sdk_example <<~JS
        const { data: customers } = await client.customers.list({
          search: 'jane',
          sort: '-created_at',
          limit: 25,
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :limit, in: :query, type: :integer, required: false
      parameter name: 'q[search]', in: :query, type: :string, required: false,
                description: 'Email + name full-text-ish search'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., addresses, store_credits). Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., email,first_name,last_name). id is always included.'

      response '200', 'customers found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end

    post 'Create a customer' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a customer. No welcome email is sent automatically.'
      admin_scope :write, :customers

      admin_sdk_example <<~JS
        const customer = await client.customers.create({
          email: 'jane@example.com',
          first_name: 'Jane',
          last_name: 'Doe',
          phone: '+1 212 555 1234',
          tags: ['wholesale'],
          accepts_email_marketing: true,
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[email],
        properties: {
          email: { type: :string, example: 'new@example.com' },
          first_name: { type: :string },
          last_name: { type: :string },
          phone: { type: :string },
          accepts_email_marketing: { type: :boolean },
          internal_note: { type: :string },
          tags: { type: :array, items: { type: :string } },
          metadata: { type: :object }
        }
      }

      response '201', 'customer created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { email: 'newcustomer@example.com', first_name: 'New', last_name: 'Customer' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['email']).to eq('newcustomer@example.com')
        end
      end
    end
  end

  path '/api/v3/admin/customers/{id}' do
    let(:id) { customer.prefixed_id }

    get 'Show a customer' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns full customer details including computed order stats (orders_count, total_spent, last_order_completed_at).'
      admin_scope :read, :customers

      admin_sdk_example <<~JS
        const customer = await client.customers.get('cus_UkLWZg9DAJ', {
          expand: ['addresses', 'store_credits'],
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Customer ID'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations: addresses, orders, store_credits, default_billing_address, default_shipping_address'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., email,first_name,last_name). id is always included.'

      response '200', 'customer found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(customer.prefixed_id)
          expect(data['email']).to eq(customer.email)
        end
      end
    end

    patch 'Update a customer' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates customer attributes. `tags` replaces the full set.'
      admin_scope :write, :customers

      admin_sdk_example <<~JS
        const customer = await client.customers.update('cus_UkLWZg9DAJ', {
          first_name: 'Updated',
          tags: ['wholesale', 'vip'],
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string },
          first_name: { type: :string },
          last_name: { type: :string },
          phone: { type: :string },
          accepts_email_marketing: { type: :boolean },
          internal_note: { type: :string },
          tags: { type: :array, items: { type: :string } },
          metadata: { type: :object }
        }
      }

      response '200', 'customer updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { first_name: 'Updated' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['first_name']).to eq('Updated')
        end
      end
    end

    delete 'Delete a customer' do
      tags 'Customers'
      security [api_key: [], bearer_auth: []]
      description 'Deletes a customer. Returns 422 if the customer has any orders.'
      admin_scope :write, :customers

      admin_sdk_example <<~JS
        await client.customers.delete('cus_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '204', 'customer deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end
end
