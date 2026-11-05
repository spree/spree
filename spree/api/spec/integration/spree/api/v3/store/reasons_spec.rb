# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Reasons API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  { return_reasons: [:return_reason, 'ReturnReason', 'Why goods come back, offered when opening a return or an exchange.'],
    claim_reasons: [:claim_reason, 'ClaimReason', 'What went wrong with a delivery, offered when filing a claim.'] }.each do |path_name, (factory, schema_name, summary)|
    path "/api/v3/store/#{path_name}" do
      get "List #{path_name.to_s.tr('_', ' ')}" do
        tags 'Orders'
        produces 'application/json'
        security [api_key: []]
        description "#{summary} Active reasons only, by name; the merchant owns the list."

        parameter name: 'x-spree-api-key', in: :header, type: :string, required: true

        response '200', 'reasons listed' do
          let(:'x-spree-api-key') { api_key.token }
          let!(:active) { create(factory, store: store, name: 'Wrong size') }
          let!(:retired) { create(factory, store: store, name: 'Retired reason', active: false) }
          let!(:elsewhere) { create(factory, store: create(:store), name: 'Another store') }

          schema SwaggerSchemaHelpers.paginated(schema_name)

          run_test! do |response|
            names = JSON.parse(response.body)['data'].map { |row| row['name'] }
            expect(names).to include('Wrong size')
            expect(names).not_to include('Retired reason', 'Another store')
          end
        end
      end
    end
  end
end
