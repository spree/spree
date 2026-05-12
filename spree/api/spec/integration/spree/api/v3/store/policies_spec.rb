# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Policies API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:return_policy) { create(:policy, owner: store, name: 'Return Policy', slug: 'return-policy', body: 'You can return items within 30 days.') }
  let!(:privacy_policy) { create(:policy, owner: store, name: 'Privacy Policy', slug: 'privacy-policy', body: 'We respect your privacy.') }

  path '/api/v3/store/policies' do
    get 'List store policies' do
      tags 'Policies'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Returns all policies for the current store (e.g., return policy, privacy policy, terms of service).
        Policies are managed in Spree Admin and contain rich text content.
      DESC

      sdk_example 'policies/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,slug). id is always included.'

      response '200', 'policies listed' do
        let(:'x-spree-api-key') { api_key.token }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref' => '#/components/schemas/Policy' }
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          slugs = data['data'].map { |p| p['slug'] }
          expect(slugs).to include('return-policy', 'privacy-policy')
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/policies/{id}' do
    get 'Get a policy' do
      tags 'Policies'
      produces 'application/json'
      security [api_key: []]
      description 'Returns a single policy by slug or prefixed ID. Includes the full rich text body.'

      sdk_example 'policies/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Policy slug (e.g., return-policy) or prefixed ID (e.g., pol_abc123)'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'policy found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { 'return-policy' }

        schema '$ref' => '#/components/schemas/Policy'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Return Policy')
          expect(data['slug']).to eq('return-policy')
          expect(data['body']).to be_present
        end
      end

      response '404', 'policy not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { 'non-existent-policy' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
