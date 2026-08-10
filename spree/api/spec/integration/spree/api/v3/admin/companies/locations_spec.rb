# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Company Locations API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:company) { create(:company, store: store, name: 'Acme Industrial') }
  let!(:location) { create(:company_location, company: company, name: 'Berlin') }
  let(:germany) { create(:country, iso: 'DE', name: 'Germany') }

  path '/api/v3/admin/companies/{company_id}/locations' do
    let(:company_id) { company.prefixed_id }

    get 'List company locations' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the branches of a business customer. Each branch owns its own addresses and the buyers authorised to purchase for it.'
      admin_scope :read, :customers

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :company_id, in: :path, type: :string, required: true

      response '200', 'locations found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(location.prefixed_id)
        end
      end
    end

    post 'Create a company location' do
      tags 'Companies'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a branch. Addresses are supplied inline and belong to the branch, so editing one later changes the branch\'s own record rather than an address the buyer also uses.'
      admin_scope :write, :customers

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :company_id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Hamburg warehouse' },
          external_id: { type: :string, nullable: true, example: 'HAM-01' },
          billing_address: {
            type: :object,
            description: 'Created inline and owned by the branch.',
            properties: {
              first_name: { type: :string }, last_name: { type: :string },
              address1: { type: :string }, city: { type: :string },
              postal_code: { type: :string }, country_iso: { type: :string, example: 'DE' }
            }
          }
        },
        required: ['name']
      }

      let(:'x-spree-api-key') { secret_api_key.plaintext_token }

      response '201', 'location created' do
        let(:body) do
          {
            name: 'Hamburg warehouse',
            billing_address: {
              first_name: 'Anna', last_name: 'Muller', address1: 'Hafenstr 1',
              city: 'Hamburg', postal_code: '20095', country_iso: germany.iso
            }
          }
        end

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('Hamburg warehouse')
        end
      end

      response '422', 'invalid request' do
        let(:body) { { external_id: 'NO-NAME' } }

        run_test!
      end
    end
  end

  path '/api/v3/admin/company_locations/{id}' do
    let(:id) { location.prefixed_id }
    let(:'x-spree-api-key') { secret_api_key.plaintext_token }

    parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
    parameter name: :Authorization, in: :header, type: :string, required: true
    parameter name: :id, in: :path, type: :string, required: true

    get 'Get a company location' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Branches are addressed by their own id once you hold one — the company id is not needed.'
      admin_scope :read, :customers

      response '200', 'location found' do
        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('Berlin')
        end
      end
    end

    patch 'Update a company location' do
      tags 'Companies'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Address fields sent here edit the branch\'s existing address in place; send only what changes.'
      admin_scope :write, :customers

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Berlin Mitte' },
          billing_address: { type: :object, properties: { city: { type: :string } } }
        }
      }

      response '200', 'location updated' do
        let(:body) { { name: 'Berlin Mitte' } }

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('Berlin Mitte')
        end
      end
    end

    delete 'Delete a company location' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Removes the branch, its buyers and the addresses it owned.'
      admin_scope :write, :customers

      response '204', 'location deleted' do
        run_test!
      end
    end
  end
end
