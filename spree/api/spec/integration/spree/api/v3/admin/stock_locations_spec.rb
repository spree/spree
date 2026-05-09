# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Stock Locations API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:stock_location) { create(:stock_location, name: 'Brooklyn warehouse') }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/stock_locations' do
    get 'List stock locations' do
      tags 'Configuration'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns the configured stock locations. Stock locations are global
        (shared across stores). Filter with Ransack predicates such as
        `q[active_eq]`, `q[kind_eq]`, `q[pickup_enabled_eq]`, or
        `q[name_cont]`.

        Pickup-related attributes (`kind`, `pickup_enabled`,
        `pickup_stock_policy`, `pickup_ready_in_minutes`,
        `pickup_instructions`) drive merchant pickup support at checkout —
        customers can collect orders from any active location with
        `pickup_enabled: true`.
      DESC
      admin_scope :read, :settings

      admin_sdk_example <<~JS
        const { data: stockLocations } = await client.stockLocations.list()
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name (contains)'
      parameter name: :'q[active_eq]', in: :query, type: :boolean, required: false,
                description: 'Filter by active status'
      parameter name: :'q[kind_eq]', in: :query, type: :string, required: false,
                description: "Filter by kind (built-in: 'warehouse', 'store', 'fulfillment_center')"
      parameter name: :'q[pickup_enabled_eq]', in: :query, type: :boolean, required: false,
                description: 'Filter by pickup-enabled flag'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort by field. Prefix with `-` for descending (e.g., `-created_at`).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'stock locations found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('StockLocation')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].map { |sl| sl['id'] }).to include(stock_location.prefixed_id)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a stock location' do
      tags 'Configuration'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Creates a new stock location.

        Setting `default: true` automatically demotes the previous default
        location.
      DESC
      admin_scope :write, :settings

      admin_sdk_example <<~JS
        const stockLocation = await client.stockLocations.create({
          name: 'Brooklyn warehouse',
          kind: 'warehouse',
          country_iso: 'US',
          state_abbr: 'NY',
          city: 'Brooklyn',
          zipcode: '11201',
          pickup_enabled: true,
          pickup_stock_policy: 'local',
          pickup_ready_in_minutes: 60,
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Brooklyn warehouse' },
          admin_name: { type: :string, nullable: true, description: 'Internal name shown only in the admin' },
          active: { type: :boolean, example: true },
          default: { type: :boolean, description: 'Setting to true demotes the previous default.' },
          kind: {
            type: :string,
            enum: Spree::StockLocation::KINDS,
            description: 'Categorizes the location.',
            example: 'warehouse'
          },
          propagate_all_variants: { type: :boolean },
          backorderable_default: { type: :boolean },
          address1: { type: :string, nullable: true },
          address2: { type: :string, nullable: true },
          city: { type: :string, nullable: true },
          zipcode: { type: :string, nullable: true },
          phone: { type: :string, nullable: true },
          company: { type: :string, nullable: true },
          country_iso: { type: :string, nullable: true, description: 'ISO-3166 alpha-2 country code (e.g. "US").' },
          state_abbr: { type: :string, nullable: true, description: 'State / province abbreviation (e.g. "NY"). Resolved against the selected country.' },
          state_name: { type: :string, nullable: true, description: 'Free-text state for countries without a states list.' },
          pickup_enabled: { type: :boolean },
          pickup_stock_policy: {
            type: :string,
            enum: Spree::StockLocation::PICKUP_STOCK_POLICIES,
            description: "'local' = items at this location only; 'any' = transfer-eligible (ship-to-store)."
          },
          pickup_ready_in_minutes: { type: :number, nullable: true, minimum: 0 },
          pickup_instructions: { type: :string, nullable: true }
        },
        required: %w[name]
      }

      response '201', 'stock location created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          {
            name: 'Manhattan store',
            kind: 'store',
            pickup_enabled: true,
            pickup_stock_policy: 'local',
            pickup_ready_in_minutes: 30
          }
        end

        schema '$ref' => '#/components/schemas/StockLocation'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Manhattan store')
          expect(data['kind']).to eq('store')
          expect(data['pickup_enabled']).to be true
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

  path '/api/v3/admin/stock_locations/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Stock location ID'

    get 'Get a stock location' do
      tags 'Configuration'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single stock location by prefixed ID.'
      admin_scope :read, :settings

      admin_sdk_example <<~JS
        const stockLocation = await client.stockLocations.get('sloc_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'stock location found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { stock_location.prefixed_id }

        schema '$ref' => '#/components/schemas/StockLocation'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(stock_location.prefixed_id)
        end
      end

      response '404', 'stock location not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'sloc_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a stock location' do
      tags 'Configuration'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Updates an existing stock location. Same address-field conventions as
        the create endpoint.

        Setting `default: true` automatically demotes the previous default.
      DESC
      admin_scope :write, :settings

      admin_sdk_example <<~JS
        const stockLocation = await client.stockLocations.update('sloc_UkLWZg9DAJ', {
          pickup_enabled: true,
          pickup_ready_in_minutes: 45,
          pickup_instructions: 'Enter through the back door, ring the bell.',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          admin_name: { type: :string, nullable: true },
          active: { type: :boolean },
          default: { type: :boolean },
          kind: { type: :string, enum: Spree::StockLocation::KINDS },
          propagate_all_variants: { type: :boolean },
          backorderable_default: { type: :boolean },
          address1: { type: :string, nullable: true },
          address2: { type: :string, nullable: true },
          city: { type: :string, nullable: true },
          zipcode: { type: :string, nullable: true },
          phone: { type: :string, nullable: true },
          company: { type: :string, nullable: true },
          country_iso: { type: :string, nullable: true },
          state_abbr: { type: :string, nullable: true },
          state_name: { type: :string, nullable: true },
          pickup_enabled: { type: :boolean },
          pickup_stock_policy: { type: :string, enum: Spree::StockLocation::PICKUP_STOCK_POLICIES },
          pickup_ready_in_minutes: { type: :number, nullable: true, minimum: 0 },
          pickup_instructions: { type: :string, nullable: true }
        }
      }

      response '200', 'stock location updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { stock_location.prefixed_id }
        let(:body) { { name: 'Renamed warehouse', pickup_enabled: true, pickup_ready_in_minutes: 45 } }

        schema '$ref' => '#/components/schemas/StockLocation'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Renamed warehouse')
          expect(data['pickup_enabled']).to be true
          expect(data['pickup_ready_in_minutes']).to eq(45)
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { stock_location.prefixed_id }
        let(:body) { { pickup_stock_policy: 'invalid' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    delete 'Delete a stock location' do
      tags 'Configuration'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Soft-deletes the stock location (sets `deleted_at`). Existing
        fulfillments that referenced it keep the historical record via
        `Spree::StockLocation.with_deleted`.
      DESC
      admin_scope :write, :settings

      admin_sdk_example <<~JS
        await client.stockLocations.delete('sloc_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '204', 'stock location deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { stock_location.prefixed_id }

        run_test!
      end
    end
  end
end
