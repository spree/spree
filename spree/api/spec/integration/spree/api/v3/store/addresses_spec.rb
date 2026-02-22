# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Addresses API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:country) { create(:country, states_required: true) }
  let!(:state) { create(:state, country: country) }
  let!(:address) { create(:address, user: user, country: country, state: state) }

  path '/api/v3/store/customer/addresses' do
    get 'List customer addresses' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all addresses in the customer address book'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'addresses found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/StoreAddress' } },
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

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          firstname: { type: :string, example: 'John' },
          lastname: { type: :string, example: 'Doe' },
          address1: { type: :string, example: '123 Main St' },
          address2: { type: :string, example: 'Apt 4B' },
          city: { type: :string, example: 'New York' },
          zipcode: { type: :string, example: '10001' },
          phone: { type: :string, example: '+1 555 123 4567' },
          company: { type: :string, example: 'Acme Inc' },
          country_iso: { type: :string, example: 'US', description: 'ISO 3166-1 alpha-2 country code (e.g., "US", "DE")' },
          state_abbr: { type: :string, example: 'NY', description: 'ISO 3166-2 subdivision code without country prefix (e.g., "CA", "NY")' },
          state_name: { type: :string, example: 'New York', description: 'State name - for countries without predefined states' }
        },
        required: %w[firstname lastname address1 city zipcode country_iso]
      }

      response '201', 'address created' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) do
          {
            firstname: 'John',
            lastname: 'Doe',
            address1: '123 Main St',
            city: 'New York',
            zipcode: '10001',
            phone: '+1 555 123 4567',
            country_iso: country.iso,
            state_abbr: state.abbr
          }
        end

        schema '$ref' => '#/components/schemas/StoreAddress'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['firstname']).to eq('John')
          expect(data['city']).to eq('New York')
          expect(data['country_iso']).to eq(country.iso)
          expect(data['state_abbr']).to eq(state.abbr)
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { firstname: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/customer/addresses/{id}' do
    get 'Get an address' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'address found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { address.to_param }

        schema '$ref' => '#/components/schemas/StoreAddress'

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

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          firstname: { type: :string, example: 'John' },
          lastname: { type: :string, example: 'Doe' },
          address1: { type: :string, example: '456 Oak Ave' },
          city: { type: :string, example: 'Los Angeles' }
        }
      }

      response '200', 'address updated' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { address.to_param }
        let(:body) { { city: 'Los Angeles' } }

        schema '$ref' => '#/components/schemas/StoreAddress'

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

  path '/api/v3/store/customer/addresses/{id}/mark_as_default' do
    patch 'Mark address as default' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Sets the address as the default billing or shipping address for the customer'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          kind: { type: :string, enum: %w[billing shipping], example: 'billing',
                  description: 'Address kind: billing or shipping' }
        },
        required: ['kind']
      }

      response '200', 'address marked as default' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { address.to_param }
        let(:body) { { kind: 'billing' } }

        schema '$ref' => '#/components/schemas/StoreAddress'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(address.prefixed_id)
          expect(user.reload.bill_address_id).to eq(address.id)
        end
      end

      response '422', 'invalid kind parameter' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { address.to_param }
        let(:body) { { kind: 'invalid' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '404', 'address not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { 'non-existent' }
        let(:body) { { kind: 'billing' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
