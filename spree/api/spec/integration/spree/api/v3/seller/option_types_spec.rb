# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Option Types API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let!(:option_type) { create(:option_type, store: store, name: 'size', label: 'Size') }
  let!(:option_value) { create(:option_value, option_type: option_type, name: 'small', label: 'Small') }

  path '/api/v3/seller/option_types' do
    get 'List option types' do
      tags 'Option Types'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        The marketplace's option types (Size, Colour), which a seller builds
        their product's variants from.

        Read only. The option types and their values are the marketplace's; a
        seller picks from them when listing. Pass `expand=option_values` for
        the values a variant may take, and send the chosen option type's
        `name` and value's `name` as a variant's `options`. A product type's
        `option_type_ids` name the option types picking it adds.
      DESC

      seller_sdk_example 'option-types/list'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to include. `option_values` adds the values.'
      filter_parameters_for

      response '200', 'option types listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:expand) { 'option_values' }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/OptionType' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          size = data.find { |item| item['id'] == option_type.prefixed_id }
          expect(size['option_values'].pluck('name')).to eq(['small'])
        end
      end
    end
  end

  path '/api/v3/seller/option_types/{id}' do
    get 'Get an option type' do
      tags 'Option Types'
      produces 'application/json'
      security [bearer_auth: []]

      seller_sdk_example 'option-types/get'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true, description: 'Option type ID'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to include. `option_values` adds the values.'

      response '200', 'option type found' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { option_type.prefixed_id }
        let(:expand) { 'option_values' }

        schema '$ref' => '#/components/schemas/OptionType'

        run_test! do |response|
          expect(JSON.parse(response.body)['label']).to eq('Size')
        end
      end
    end
  end
end
