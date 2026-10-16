# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Tax Exemption Reasons API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:reason) { create(:tax_exemption_reason, store: store, name: 'Reseller (wholesale)', code: 'G') }

  path '/api/v3/admin/tax_exemption_reasons' do
    get 'List tax exemption reasons' do
      tags 'Reasons'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Why a business buys without tax — the reasons a merchant can record on a
        tax exemption certificate. Each has the merchant's own `name` and a `code`,
        which certificates record and the tax provider receives.

        The vocabulary is the merchant's own — seeded with a starting set and
        edited from the dashboard. A provider whose engine reads the code lists
        the codes it understands on `GET /tax_providers`. Inactive rows stay on the
        certificates that already record them, but are not offered on new ones.
      DESC
      admin_scope :read, :settings

      admin_sdk_example 'tax-exemption-reasons/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      filter_parameters_for
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort by field. Prefix with `-` for descending (e.g., `-created_at`).'

      response '200', 'tax exemption reasons found' do
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

    post 'Create a tax exemption reason' do
      tags 'Reasons'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Adds a tax exemption reason to this store. Names and codes are unique per store.'
      admin_scope :write, :settings

      admin_sdk_example 'tax-exemption-reasons/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      request_body_for

      response '201', 'tax exemption reason created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'Federal government', code: 'A' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Federal government')
          expect(data['code']).to eq('A')
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

  path '/api/v3/admin/tax_exemption_reasons/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Tax exemption reason ID'

    get 'Get a tax exemption reason' do
      tags 'Reasons'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single tax exemption reason by prefixed ID.'
      admin_scope :read, :settings

      admin_sdk_example 'tax-exemption-reasons/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'tax exemption reason found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { reason.prefixed_id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(reason.prefixed_id)
          expect(data['code']).to eq('G')
        end
      end

      response '404', 'tax exemption reason not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'txr_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a tax exemption reason' do
      tags 'Reasons'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Renames a tax exemption reason or retires it. Deactivating keeps it on the
        certificates that already record it while removing it from the pickers. The
        code is fixed once a certificate records it.
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'tax-exemption-reasons/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      request_body_for

      response '200', 'tax exemption reason updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { reason.prefixed_id }
        let(:body) { { active: false } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['active']).to be(false)
        end
      end
    end

    delete 'Delete a tax exemption reason' do
      tags 'Reasons'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Removes a tax exemption reason the store no longer uses. A reason a
        certificate records is refused — deactivate it instead.
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'tax-exemption-reasons/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '204', 'tax exemption reason deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { reason.prefixed_id }

        run_test!
      end
    end
  end
end
