# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Allowed Origins API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:allowed_origin) { create(:allowed_origin, store: store, origin: 'https://shop.example.com') }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/allowed_origins' do
    get 'List allowed origins' do
      tags 'Configuration'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns the CORS allowlist for the current store. Each entry is a
        bare `scheme://host[:port]` permitted to call the admin API from a
        browser. Backs the `Rack::Cors` allowlist and the CSRF boundary of
        the admin cookie session (see
        `docs/plans/5.5-admin-auth-cookie-refresh.md`).
      DESC
      admin_scope :read, :settings

      admin_sdk_example 'allowed-origins/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[origin_cont]', in: :query, type: :string, required: false,
                description: 'Filter by origin (contains)'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort by field. Prefix with `-` for descending (e.g., `-created_at`).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'allowed origins found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('AllowedOrigin')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].map { |o| o['id'] }).to include(allowed_origin.prefixed_id)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create an allowed origin' do
      tags 'Configuration'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Adds an origin to the admin CORS allowlist. The value must be a bare
        `scheme://host[:port]` (no path, query, or fragment) and use `http` or
        `https`.
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'allowed-origins/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          origin: { type: :string, example: 'https://admin.example.com' }
        },
        required: %w[origin]
      }

      response '201', 'allowed origin created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { origin: 'https://admin.example.com' } }

        schema '$ref' => '#/components/schemas/AllowedOrigin'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['origin']).to eq('https://admin.example.com')
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { origin: 'not a url' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/allowed_origins/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Allowed origin ID'

    get 'Get an allowed origin' do
      tags 'Configuration'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single allowed origin by prefixed ID.'
      admin_scope :read, :settings

      admin_sdk_example 'allowed-origins/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'allowed origin found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { allowed_origin.prefixed_id }

        schema '$ref' => '#/components/schemas/AllowedOrigin'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(allowed_origin.prefixed_id)
        end
      end

      response '404', 'allowed origin not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'ao_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update an allowed origin' do
      tags 'Configuration'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates an existing allowed origin.'
      admin_scope :write, :settings

      admin_sdk_example 'allowed-origins/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          origin: { type: :string }
        }
      }

      response '200', 'allowed origin updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { allowed_origin.prefixed_id }
        let(:body) { { origin: 'https://www.example.com' } }

        schema '$ref' => '#/components/schemas/AllowedOrigin'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['origin']).to eq('https://www.example.com')
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { allowed_origin.prefixed_id }
        let(:body) { { origin: 'https://example.com/with-path' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    delete 'Delete an allowed origin' do
      tags 'Configuration'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Removes an origin from the admin CORS allowlist. After deletion the
        admin SPA running at that origin will no longer be able to call the
        admin API from a browser.
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'allowed-origins/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '204', 'allowed origin deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { allowed_origin.prefixed_id }

        run_test!
      end
    end
  end
end
