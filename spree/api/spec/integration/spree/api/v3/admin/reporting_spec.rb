# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Reporting API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/reporting/query' do
    post 'Run a reporting query' do
      tags 'Reports'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Runs a query against the store's registered metrics and dimensions, in
        the store's time zone. A metric or dimension the registry does not know
        is refused with the names that are valid, and an API key needs the read
        scope of every resource the query touches.
      DESC
      admin_scope :read, :reports

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      request_body_for

      response '200', 'query results' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          {
            metrics: %w[total_sales orders],
            dimensions: [{ name: 'completed_at', grain: 'day' }],
            time_range: { preset: 'last_7_days' },
            compare: 'previous_period'
          }
        end

        before { create(:completed_order_with_totals, store: store, completed_at: 2.days.ago) }

        run_test! do |response|
          expect(JSON.parse(response.body)).to have_key('rows')
        end
      end
    end
  end
end
