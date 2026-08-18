# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Sellers API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:seller) { create(:seller, store: store, name: 'Sparks Audio', status: 'approved') }
  let!(:pending_seller) { create(:seller, store: store, name: 'Not Yet', status: 'pending') }

  path '/api/v3/store/sellers' do
    get 'List sellers' do
      tags 'Sellers'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Returns the sellers on this marketplace that a shopper can currently
        buy from. A seller still onboarding, suspended, or away on holiday is
        not listed — showing them would advertise a seller whose products
        cannot be bought.

        The payload is the seller's public profile only. Nothing about how the
        marketplace runs them — status, payout schedule, tax handling, contact
        addresses — is exposed here.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :limit, in: :query, type: :integer, required: false
      parameter name: 'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'sellers found' do
        let(:'x-spree-api-key') { api_key.token }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Seller' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          ids = data['data'].pluck('id')
          expect(ids).to include(seller.prefixed_id)
          expect(ids).not_to include(pending_seller.prefixed_id)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/sellers/{id}' do
    get 'Get a seller' do
      tags 'Sellers'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Returns a single seller's public profile, by slug or prefixed ID, so a
        storefront can route `/sellers/sparks-audio` without holding an id.

        A seller who cannot currently sell returns 404 rather than a profile.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Seller slug (e.g., sparks-audio) or prefixed ID (e.g., sel_abc123)'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'seller found by slug' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { seller.slug }

        schema '$ref' => '#/components/schemas/Seller'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Sparks Audio')
          expect(data).not_to have_key('status')
        end
      end

      response '404', 'seller not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { pending_seller.slug }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
