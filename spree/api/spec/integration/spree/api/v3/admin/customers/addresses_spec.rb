# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Customer Addresses API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:customer) { create(:user) }
  let!(:address) { create(:address, user: customer) }
  let(:country) { address.country }
  let(:state) { address.state }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/customers/{customer_id}/addresses' do
    let(:customer_id) { customer.prefixed_id }

    get 'List customer addresses' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the customer\'s saved addresses.'
      admin_scope :read, :customers

      admin_sdk_example 'customer-addresses/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :customer_id, in: :path, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., country, state). Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., first_name,last_name,address1,city). id is always included.'

      response '200', 'addresses found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end

    post 'Create a customer address' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Adds a new address to the customer\'s address book. Pass `is_default_billing: true` or `is_default_shipping: true` to set as the default — the previous default loses its flag in the same transaction.'
      admin_scope :write, :customers

      admin_sdk_example 'customer-addresses/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :customer_id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          first_name: { type: :string },
          last_name: { type: :string },
          address1: { type: :string },
          address2: { type: :string },
          city: { type: :string },
          postal_code: { type: :string },
          country_iso: { type: :string, description: 'ISO-2 country code (e.g. US)' },
          state_abbr: { type: :string, description: 'State/province abbreviation (e.g. NY)' },
          phone: { type: :string },
          company: { type: :string },
          label: { type: :string },
          is_default_billing: { type: :boolean },
          is_default_shipping: { type: :boolean }
        }
      }

      response '201', 'address created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          {
            first_name: 'Jane', last_name: 'Doe',
            address1: '350 Fifth Avenue', city: 'New York', postal_code: '10118',
            country_iso: 'US', state_abbr: 'NY', phone: '+12125551234',
            label: 'Office'
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['city']).to eq('New York')
        end
      end
    end
  end

  path '/api/v3/admin/customers/{customer_id}/addresses/{id}' do
    let(:customer_id) { customer.prefixed_id }
    let(:id) { address.prefixed_id }

    patch 'Update a customer address' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a customer address.'
      admin_scope :write, :customers

      admin_sdk_example 'customer-addresses/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :customer_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          city: { type: :string },
          is_default_billing: { type: :boolean },
          is_default_shipping: { type: :boolean }
        }
      }

      response '200', 'address updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { city: 'Manhattan' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['city']).to eq('Manhattan')
        end
      end
    end

    delete 'Delete a customer address' do
      tags 'Customers'
      security [api_key: [], bearer_auth: []]
      description 'Deletes the address. If it was a default, the customer loses that default (no auto-promotion).'
      admin_scope :write, :customers

      admin_sdk_example 'customer-addresses/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :customer_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '204', 'address deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end
end
