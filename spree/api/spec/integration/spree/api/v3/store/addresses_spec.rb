# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Addresses API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:address) { create(:address, user: user) }
  let(:country) { address.country }
  let(:state) { address.state }

  path '/api/v3/store/customers/me/addresses' do
    get 'List customer addresses' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all addresses in the customer address book'

      sdk_example 'customer-addresses/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :limit, in: :query, type: :integer, required: false
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,slug,price). id is always included.'

      response '200', 'addresses found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Address' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create an address' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Adds a new address to the customer address book'

      sdk_example 'customer-addresses/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          first_name: { type: :string, example: 'John' },
          last_name: { type: :string, example: 'Doe' },
          address1: { type: :string, example: '123 Main St' },
          address2: { type: :string, example: 'Apt 4B' },
          city: { type: :string, example: 'New York' },
          postal_code: { type: :string, example: '10001' },
          phone: { type: :string, example: '+1 555 123 4567' },
          company: { type: :string, example: 'Acme Inc' },
          country_iso: { type: :string, example: 'US', description: 'ISO 3166-1 alpha-2 country code (e.g., "US", "DE")' },
          state_abbr: { type: :string, example: 'NY', description: 'ISO 3166-2 subdivision code without country prefix (e.g., "CA", "NY")' },
          state_name: { type: :string, example: 'New York', description: 'State name - for countries without predefined states' },
          is_default_billing: { type: :boolean, example: true, description: 'Set as default billing address' },
          is_default_shipping: { type: :boolean, example: true, description: 'Set as default shipping address' }
        },
        required: %w[first_name last_name address1 city postal_code country_iso]
      }

      response '201', 'address created' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) do
          {
            first_name: 'John',
            last_name: 'Doe',
            address1: '123 Main St',
            city: 'New York',
            postal_code: '10001',
            phone: '+1 555 123 4567',
            country_iso: country.iso,
            state_abbr: state.abbr
          }
        end

        schema '$ref' => '#/components/schemas/Address'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['first_name']).to eq('John')
          expect(data['city']).to eq('New York')
          expect(data['country_iso']).to eq(country.iso)
          expect(data['state_abbr']).to eq(state.abbr)
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { first_name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/customers/me/addresses/{id}' do
    get 'Get an address' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]

      sdk_example 'customer-addresses/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,slug,price). id is always included.'

      response '200', 'address found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { address.to_param }

        schema '$ref' => '#/components/schemas/Address'

        run_test!
      end

      response '404', 'address not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { 'non-existent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update an address' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]

      sdk_example 'customer-addresses/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          first_name: { type: :string, example: 'John' },
          last_name: { type: :string, example: 'Doe' },
          address1: { type: :string, example: '456 Oak Ave' },
          city: { type: :string, example: 'Los Angeles' },
          is_default_billing: { type: :boolean, example: true, description: 'Set as default billing address' },
          is_default_shipping: { type: :boolean, example: true, description: 'Set as default shipping address' }
        }
      }

      response '200', 'address updated' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { address.to_param }
        let(:body) { { city: 'Los Angeles' } }

        schema '$ref' => '#/components/schemas/Address'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['city']).to eq('Los Angeles')
        end
      end
    end

    delete 'Delete an address' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]

      sdk_example 'customer-addresses/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '204', 'address deleted' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { address.to_param }

        run_test!
      end

      response '404', 'address not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { 'non-existent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

end
