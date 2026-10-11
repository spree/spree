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
  end
end
