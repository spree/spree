# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Reporting API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/reporting/query' do
    post 'Run a reporting query' do
      tags 'Reports'
      agent_tool false, reason: 'query_report runs this query, with describe_reporting to learn the vocabulary first.'
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

      admin_sdk_example 'reporting/query'

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

        metric_value = {
          type: :object,
          properties: {
            value: { description: 'A decimal string for a money metric, a number for a count' },
            display: { type: :string, description: 'The value formatted with its currency. Money metrics only.' },
            previous: { description: 'The value in the period compared against. Present when the query asks for a comparison.' },
            growth: {
              type: :string, nullable: true,
              description: 'Percentage change from the previous period; null when that period has nothing to compare with'
            }
          },
          required: %w[value]
        }
        time_range = { type: :object, properties: { since: { type: :string }, until: { type: :string } }, required: %w[since until] }

        schema type: :object,
               properties: {
                 meta: {
                   type: :object,
                   properties: {
                     currency: { type: :string, example: 'USD' },
                     time_range: time_range,
                     previous_time_range: time_range.merge(nullable: true),
                     metrics: { type: :array, items: { type: :string } },
                     dimensions: {
                       type: :array,
                       items: { type: :object, properties: { name: { type: :string }, grain: { type: :string } }, required: %w[name] }
                     }
                   },
                   required: %w[currency time_range metrics dimensions]
                 },
                 totals: { type: :object, description: 'Keyed by metric', additionalProperties: metric_value },
                 rows: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       dimensions: {
                         type: :object,
                         description: 'Keyed by dimension: the value itself for a time bucket or a status, ' \
                                      'and `{ id, label, meta }` for a record such as a product or a customer',
                         additionalProperties: true
                       },
                       metrics: { type: :object, description: 'Keyed by metric', additionalProperties: metric_value }
                     },
                     required: %w[dimensions metrics]
                   }
                 }
               },
               required: %w[meta totals rows]

        run_test! do |response|
          expect(JSON.parse(response.body)).to have_key('rows')
        end
      end
    end
  end
end
