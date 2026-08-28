# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Policies API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:policy) do
    create(:policy, owner: store, name: 'Restocking Policy', slug: 'restocking-policy',
                    body: '<p>Return anything unopened within 30 days.</p>')
  end
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/policies' do
    get 'List policies' do
      tags 'Policies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns the store's policy documents — terms of service, privacy
        policy, returns policy, shipping policy, and any others the merchant
        has written. Every store is created with the four standard policies,
        named but empty.

        A marketplace seller's own policies are managed by the seller and are
        not listed here.
      DESC
      admin_scope :read, :settings

      admin_sdk_example 'policies/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name (contains)'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'policies listed' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('Policy')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].map { |p| p['id'] }).to include(policy.prefixed_id)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a policy' do
      tags 'Policies'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Creates a policy. `body` accepts HTML and is sanitized before it is
        stored; the stored markup is returned as `body_html`, and `body` reads
        back as plain text.

        The slug is derived from the name when one is not given, and is what
        the storefront addresses the policy by.
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'policies/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Wholesale Policy' },
          slug: { type: :string, example: 'wholesale-policy' },
          body: { type: :string, example: '<p>Trade orders ship within five working days.</p>' }
        },
        required: %w[name]
      }

      response '201', 'policy created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          { name: 'Wholesale Policy', body: '<p>Trade orders ship within five working days.</p>' }
        end

        schema '$ref' => '#/components/schemas/Policy'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Wholesale Policy')
          expect(data['slug']).to eq('wholesale-policy')
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { body: '<p>A policy with no name.</p>' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/policies/{id}' do
    parameter name: :id, in: :path, type: :string, required: true,
              description: 'Policy prefixed ID or slug'

    get 'Get a policy' do
      tags 'Policies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single policy, addressed by prefixed ID or by slug.'
      admin_scope :read, :settings

      admin_sdk_example 'policies/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'policy found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { policy.prefixed_id }

        schema '$ref' => '#/components/schemas/Policy'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(policy.prefixed_id)
        end
      end

      response '404', 'policy not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'pol_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a policy' do
      tags 'Policies'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a policy. `body` accepts HTML and is sanitized before it is stored.'
      admin_scope :write, :settings

      admin_sdk_example 'policies/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          slug: { type: :string },
          body: { type: :string }
        }
      }

      response '200', 'policy updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { policy.prefixed_id }
        let(:body) { { body: '<p>Return anything unopened within 60 days.</p>' } }

        schema '$ref' => '#/components/schemas/Policy'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['body_html']).to include('60 days')
        end
      end
    end

    delete 'Delete a policy' do
      tags 'Policies'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Deletes a policy. The four policies a store is created with can be
        deleted like any other — they are conventions, not fixtures.
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'policies/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '204', 'policy deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { policy.prefixed_id }

        run_test!
      end
    end
  end
end
