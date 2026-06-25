# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Product Translations API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:product) { create(:product, name: 'Espresso Machine', store: store) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  before { configure_supported_locales(store, %w[en de fr]) }

  path '/api/v3/admin/products/{product_id}/translations' do
    let(:product_id) { product.prefixed_id }

    get 'List product translations' do
      tags 'Products'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the full translation matrix for the product: the source value and content type per translatable field, plus the translated value for every supported locale.'
      admin_scope :read, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :product_id, in: :path, type: :string, required: true

      response '200', 'translations found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        before { Mobility.with_locale(:de) { product.update!(name: 'Espressomaschine') } }

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data['resource_type']).to eq('product')
          expect(data['default_locale']).to eq('en')
          expect(data['translations']['de']['name']).to eq('Espressomaschine')
        end
      end
    end

  end
end
