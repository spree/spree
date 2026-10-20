# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Saved Reports API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:saved_report) { create(:saved_report, store: store, name: 'Sales by channel') }

  path '/api/v3/admin/reporting/saved_reports' do
    get 'List saved reports' do
      tags 'Reports'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description "Returns the store's saved reports, each a named query staff can run again."
      admin_scope :read, :reports

      admin_sdk_example 'reporting/saved-reports/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      filter_parameters_for

      response '200', 'saved reports found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('SavedReport')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(saved_report.prefixed_id)
        end
      end
    end

    post 'Create a saved report' do
      tags 'Reports'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Saves a reporting query under a name so staff can run it again. The query is validated against the reporting registry.'
      admin_scope :write, :reports

      admin_sdk_example 'reporting/saved-reports/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      request_body_for

      response '201', 'saved report created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          {
            name: 'Orders by channel',
            description: 'Weekly review',
            query: { metrics: %w[total_sales orders], dimensions: %w[channel] }
          }
        end

        schema '$ref' => '#/components/schemas/SavedReport'

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('Orders by channel')
        end
      end
    end
  end

  path '/api/v3/admin/reporting/saved_reports/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Saved report ID'

    let(:id) { saved_report.prefixed_id }

    patch 'Update a saved report' do
      tags 'Reports'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :reports

      admin_sdk_example 'reporting/saved-reports/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      request_body_for

      response '200', 'saved report updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'Sales by channel (monthly)', description: 'For the board pack' } }

        schema '$ref' => '#/components/schemas/SavedReport'

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('Sales by channel (monthly)')
        end
      end
    end
  end
end
