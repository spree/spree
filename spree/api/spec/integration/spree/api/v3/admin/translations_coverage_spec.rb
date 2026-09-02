# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Translations Coverage API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/translations' do
    get 'Translation coverage for a resource type' do
      tags 'Products'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Reports how much of each record is translated into each of the store\'s non-default locales, ' \
                  'plus per-locale totals. A record counts as covered for a locale only when every one of its ' \
                  'translatable fields is filled in.'
      admin_scope :read, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :resource_type, in: :query, type: :string, required: true,
                description: 'A translatable resource type, e.g. `product`, `category`, `option_type`.'
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :limit, in: :query, type: :integer, required: false

      response '200', 'coverage found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:resource_type) { 'product' }

        before do
          configure_supported_locales(store, %w[en de])
          product = create(:product, store: store, name: 'Espresso Machine')
          Mobility.with_locale(:de) { product.update!(name: 'Espressomaschine') }
        end

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data['resource_type']).to eq('product')
          expect(data['locales']).to eq(['de'])
          expect(data['records'].first['locales']).to have_key('de')
        end
      end

      response '404', 'resource type is not translatable' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:resource_type) { 'order' }

        run_test!
      end
    end
  end
end
