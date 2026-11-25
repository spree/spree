# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Tax Providers API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  before do
    stub_const('SpecCatalogProvider', Class.new(Spree::TaxProvider::Base) do
      def self.tax_codes(_store, query:)
        [{ code: 'PC040100', description: 'Clothing and related products (business-to-consumer)' }].
          select { |code| code[:description].downcase.include?(query.downcase) }
      end
    end)
    Spree.tax_providers << SpecCatalogProvider
  end

  after { Spree.tax_providers.delete(SpecCatalogProvider) }

  path '/api/v3/admin/tax_providers/{id}/tax_codes' do
    get "Search a tax provider's tax codes" do
      tags 'Settings'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Searches the tax codes a tax engine defines, by a word in the description
        or the start of a code, for setting a tax category's `tax_code`. Only
        engines with `tax_code_lookup: true` on `GET /tax_providers` have codes to
        search; any other engine answers an empty list, as does a query shorter
        than two characters.

        A tax category may still hold a code this search does not list.
      DESC
      admin_scope :read, :settings
      agent_tool true

      admin_sdk_example 'tax-providers/tax-codes'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'The tax provider id, as listed on `GET /tax_providers` (for example `avalara`)'
      parameter name: :q, in: :query, type: :string, required: true,
                description: 'A word from the description or the start of a code, at least two characters'

      response '200', 'tax codes found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'spec_catalog_provider' }
        let(:q) { 'clothing' }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       code: { type: :string, example: 'PC040100' },
                       description: { type: :string, example: 'Clothing and related products (business-to-consumer)' }
                     },
                     required: %w[code description]
                   }
                 }
               },
               required: %w[data]

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].map { |code| code['code'] }).to eq(['PC040100'])
        end
      end

      response '404', 'tax provider not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'unknown' }
        let(:q) { 'clothing' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }
        let(:id) { 'spec_catalog_provider' }
        let(:q) { 'clothing' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
