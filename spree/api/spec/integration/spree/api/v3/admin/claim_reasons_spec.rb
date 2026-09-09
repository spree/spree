# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Claim Reasons API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:reason) { create(:claim_reason, store: store, name: 'Arrived damaged') }

  path '/api/v3/admin/claim_reasons' do
    get 'List claim reasons' do
      tags 'Reasons'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Why a customer raised a claim — what the merchant got wrong, rather than a change of mind.

        The vocabulary is the merchant's own — seeded with a starting set and
        edited from the dashboard. Inactive rows stay for the records that
        already reference them, but are not offered on new ones.
      DESC
      admin_scope :read, :settings

      admin_sdk_example 'claim-reasons/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name (contains)'
      parameter name: :'q[active_eq]', in: :query, type: :boolean, required: false,
                description: 'Filter by active flag'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort by field. Prefix with `-` for descending (e.g., `-created_at`).'

      response '200', 'claim reasons found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].map { |r| r['id'] }).to include(reason.prefixed_id)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a claim reason' do
      tags 'Reasons'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Adds a claim reason to this store. Names are unique per store, ignoring case.'
      admin_scope :write, :settings

      admin_sdk_example 'claim-reasons/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[name],
        properties: {
          name: { type: :string, example: 'Arrived damaged' },
          active: { type: :boolean, example: true, description: 'Inactive reasons are hidden from the pickers on new records.' }
        }
      }

      response '201', 'claim reason created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'A new reason' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('A new reason')
          expect(data['active']).to be(true)
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

  path '/api/v3/admin/claim_reasons/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Claim reason ID'

    get 'Get a claim reason' do
      tags 'Reasons'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single claim reason by prefixed ID.'
      admin_scope :read, :settings

      admin_sdk_example 'claim-reasons/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'claim reason found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { reason.prefixed_id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(reason.prefixed_id)
          expect(data['name']).to eq('Arrived damaged')
        end
      end

      response '404', 'claim reason not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'clr_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a claim reason' do
      tags 'Reasons'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Renames a claim reason or retires it. Deactivating keeps it on the records
        that already carry it while removing it from the pickers.
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'claim-reasons/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          active: { type: :boolean }
        }
      }

      response '200', 'claim reason updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { reason.prefixed_id }
        let(:body) { { active: false } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['active']).to be(false)
        end
      end
    end

    delete 'Delete a claim reason' do
      tags 'Reasons'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Removes a claim reason the store no longer uses. A reason already recorded
        on a document is refused — deactivate it instead, so the history it
        explains stays readable.
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'claim-reasons/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '204', 'claim reason deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { reason.prefixed_id }

        run_test!
      end
    end
  end
end
