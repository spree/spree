# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Suppliers API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:supplier_record) { create(:supplier, :with_address, store: store, name: 'Acme Wholesale') }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/suppliers' do
    get 'List suppliers' do
      tags 'Suppliers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Who the merchant buys stock from. A supplier is an address-book entry
        with a purchasing history — not a party that sells on the store, which
        is a seller.

        Suppliers belong to one store, and are soft-deleted so the purchase
        orders that name them stay readable.

        Filter with Ransack predicates such as
        `q[name_or_contact_name_or_email_cont]` or `q[country_code_eq]`.
      DESC
      admin_scope :read, :purchasing

      admin_sdk_example 'suppliers/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[name_or_contact_name_or_email_cont]', in: :query, type: :string, required: false,
                description: 'Search by name, contact name or email'

      response '200', 'suppliers found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('Supplier')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].map { |row| row['name'] }).to include('Acme Wholesale')
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a supplier' do
      tags 'Suppliers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Adds a supplier to this store's address book. The address is inline —
        street, city, state and country live on the supplier itself, the same
        shape a stock location uses.
      DESC
      admin_scope :write, :purchasing

      admin_sdk_example 'suppliers/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :supplier, in: :body, required: true, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Northwind Trading' },
          contact_name: { type: :string, nullable: true, example: 'Dana Okafor' },
          email: { type: :string, nullable: true, example: 'sales@northwind.test' },
          phone: { type: :string, nullable: true, example: '555-0100' },
          notes: { type: :string, nullable: true },
          address1: { type: :string, nullable: true, example: '1 Warehouse Way' },
          address2: { type: :string, nullable: true },
          city: { type: :string, nullable: true, example: 'Brooklyn' },
          state_code: { type: :string, nullable: true, example: 'NY' },
          state_name: { type: :string, nullable: true },
          country_code: { type: :string, nullable: true, example: 'US' },
          postal_code: { type: :string, nullable: true, example: '11201' },
          metadata: { type: :object, nullable: true }
        },
        required: %w[name]
      }

      response '201', 'supplier created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:supplier) do
          {
            name: 'Northwind Trading',
            contact_name: 'Dana Okafor',
            email: 'sales@northwind.test',
            city: 'Brooklyn',
            country_code: 'US'
          }
        end

        schema '$ref' => '#/components/schemas/Supplier'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Northwind Trading')
          expect(data['email']).to eq('sales@northwind.test')
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:supplier) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/suppliers/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Supplier ID'

    get 'Get a supplier' do
      tags 'Suppliers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :purchasing

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'supplier found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { supplier_record.prefixed_id }

        schema '$ref' => '#/components/schemas/Supplier'

        run_test!
      end

      response '404', 'supplier not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'sup_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a supplier' do
      tags 'Suppliers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :purchasing

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :supplier, in: :body, required: true, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          contact_name: { type: :string, nullable: true },
          email: { type: :string, nullable: true },
          phone: { type: :string, nullable: true }
        }
      }

      response '200', 'supplier updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { supplier_record.prefixed_id }
        let(:supplier) { { contact_name: 'Sam Reyes' } }

        schema '$ref' => '#/components/schemas/Supplier'

        run_test!
      end
    end

    delete 'Delete a supplier' do
      tags 'Suppliers'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Soft-deletes the supplier, so the purchase orders naming it stay
        readable. Refused with a 422 while a purchase order still points at it.
      DESC
      admin_scope :write, :purchasing

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '204', 'supplier deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { supplier_record.prefixed_id }

        run_test!
      end
    end
  end
end
