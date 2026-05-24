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

      admin_sdk_example 'customers/list'

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

      admin_sdk_example 'customers/create'

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

      admin_sdk_example 'customers/get'

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

      admin_sdk_example 'customers/update'

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

      admin_sdk_example 'customers/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '204', 'customer deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end

  path '/api/v3/admin/customers/bulk_add_to_groups' do
    post 'Bulk-add customers to groups' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Attaches each customer in `ids` to every group in `customer_group_ids`.
        Idempotent — customers already in a group are skipped server-side.
        Groups from sibling stores are silently ignored. Returns counts of
        customers and groups that were processed (post store-scoping).
      DESC
      admin_scope :write, :customers

      admin_sdk_example 'customers/bulk-add-to-groups'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[ids customer_group_ids],
        properties: {
          ids: { type: :array, items: { type: :string }, example: ['cus_UkLWZg9DAJ', 'cus_QrLWXg9CAJ'] },
          customer_group_ids: { type: :array, items: { type: :string }, example: ['cg_UkLWZg9DAJ'] }
        }
      }

      response '200', 'customers added to groups' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:alice) { create(:user) }
        let(:vip_group) { create(:customer_group, store: store, name: 'VIPs') }
        let(:body) { { ids: [alice.prefixed_id], customer_group_ids: [vip_group.prefixed_id] } }

        schema type: :object, properties: {
          customer_count: { type: :integer },
          customer_group_count: { type: :integer }
        }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to eq('customer_count' => 1, 'customer_group_count' => 1)
        end
      end
    end
  end

  path '/api/v3/admin/customers/bulk_remove_from_groups' do
    post 'Bulk-remove customers from groups' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Detaches each customer in `ids` from every group in `customer_group_ids`.
        No-op for non-members. Groups from sibling stores are silently ignored.
      DESC
      admin_scope :write, :customers

      admin_sdk_example 'customers/bulk-remove-from-groups'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[ids customer_group_ids],
        properties: {
          ids: { type: :array, items: { type: :string }, example: ['cus_UkLWZg9DAJ'] },
          customer_group_ids: { type: :array, items: { type: :string }, example: ['cg_UkLWZg9DAJ'] }
        }
      }

      response '200', 'customers removed from groups' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:alice) { create(:user) }
        let(:vip_group) { create(:customer_group, store: store, name: 'VIPs') }
        let(:body) { { ids: [alice.prefixed_id], customer_group_ids: [vip_group.prefixed_id] } }

        before { vip_group.customers << alice }

        schema type: :object, properties: {
          customer_count: { type: :integer },
          customer_group_count: { type: :integer }
        }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to eq('customer_count' => 1, 'customer_group_count' => 1)
        end
      end
    end
  end

  path '/api/v3/admin/customers/bulk_add_tags' do
    post 'Bulk-add tags to customers' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Adds each tag name in `tags` to every customer in `ids`. Tags are
        upserted by name; re-adding an existing tag is a no-op.
      DESC
      admin_scope :write, :customers

      admin_sdk_example 'customers/bulk-add-tags'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[ids tags],
        properties: {
          ids: { type: :array, items: { type: :string }, example: ['cus_UkLWZg9DAJ'] },
          tags: { type: :array, items: { type: :string }, example: %w[vip newsletter] }
        }
      }

      response '200', 'tags added' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:alice) { create(:user) }
        let(:body) { { ids: [alice.prefixed_id], tags: %w[vip newsletter] } }

        schema type: :object, properties: {
          customer_count: { type: :integer },
          tag_count: { type: :integer }
        }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to eq('customer_count' => 1, 'tag_count' => 2)
          expect(alice.reload.tag_list).to include('vip', 'newsletter')
        end
      end
    end
  end

  path '/api/v3/admin/customers/bulk_remove_tags' do
    post 'Bulk-remove tags from customers' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Removes each tag name in `tags` from every customer in `ids`. No-op
        for customers that don't carry the tag.
      DESC
      admin_scope :write, :customers

      admin_sdk_example 'customers/bulk-remove-tags'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[ids tags],
        properties: {
          ids: { type: :array, items: { type: :string }, example: ['cus_UkLWZg9DAJ'] },
          tags: { type: :array, items: { type: :string }, example: ['vip'] }
        }
      }

      response '200', 'tags removed' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:alice) { create(:user, tag_list: %w[vip newsletter]) }
        let(:body) { { ids: [alice.prefixed_id], tags: ['vip'] } }

        schema type: :object, properties: {
          customer_count: { type: :integer },
          tag_count: { type: :integer }
        }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to eq('customer_count' => 1, 'tag_count' => 1)
          expect(alice.reload.tag_list).not_to include('vip')
          expect(alice.reload.tag_list).to include('newsletter')
        end
      end
    end
  end
end
