# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Tax Rates API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:tax_category) { create(:tax_category) }
  let!(:germany) { Spree::Country.by_iso('DE') }
  let!(:tax_rate) { create(:tax_rate, tax_category: tax_category, country_code: germany&.iso, amount: 0.19, included_in_price: true) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/tax_rates' do
    get 'List tax rates' do
      tags 'Settings'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns the store's tax rates. Rates are the entire configuration of
        the built-in tax provider: each pairs a tax category with a jurisdiction
        (a country, optionally narrowed to one state) and a percentage, and
        decides whether the tax is already included in the product price
        (VAT-style) or added on top (US-style).

        Markets using an external tax provider ignore these rows — that
        provider carries its own jurisdiction data.
      DESC
      admin_scope :read, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name (contains)'
      parameter name: :'q[included_in_price_true]', in: :query, type: :boolean, required: false,
                description: 'Only rates included in the product price'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort by field. Prefix with `-` for descending (e.g., `-created_at`).'

      response '200', 'tax rates found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('TaxRate')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].map { |rate| rate['id'] }).to include(tax_rate.prefixed_id)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a tax rate' do
      tags 'Settings'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Creates a tax rate for the current store. Give either `amount` as a
        decimal (`0.19`) or `amount_percentage` as a percentage (`19`).

        Name the jurisdiction with `country_code` (and `state_code` for a
        state-level rate). Omitting the country makes the rate apply everywhere.

        Set `included_in_price` for VAT-style pricing, where the rate is backed
        out of the displayed price rather than added to it.
      DESC
      admin_scope :write, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          name: { type: :string, description: 'Customer-facing rate name, e.g. "VAT"' },
          amount: { type: :string, description: 'Rate as a decimal, e.g. "0.19"' },
          amount_percentage: { type: :number, description: 'Rate as a percentage, e.g. 19' },
          included_in_price: { type: :boolean },
          show_rate_in_label: { type: :boolean },
          tax_category_id: { type: :string },
          country_code: { type: :string, description: 'ISO code, e.g. "DE". Omit for every country.' },
          state_code: { type: :string, description: 'State abbreviation within that country, e.g. "CA".' }
        },
        required: %w[name tax_category_id]
      }

      response '201', 'tax rate created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          { name: 'VAT', amount_percentage: 19, included_in_price: true,
            tax_category_id: tax_category.prefixed_id, country_code: 'DE' }
        end

        schema '$ref' => '#/components/schemas/TaxRate'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['amount']).to eq('0.19')
          expect(data['amount_percentage']).to eq(19.0)
        end
      end

      response '422', 'validation failed' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { amount_percentage: 19 } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/tax_rates/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Tax rate ID'

    let(:id) { tax_rate.prefixed_id }

    get 'Get a tax rate' do
      tags 'Settings'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'tax rate found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema '$ref' => '#/components/schemas/TaxRate'

        run_test!
      end
    end

    patch 'Update a tax rate' do
      tags 'Settings'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          amount: { type: :string },
          amount_percentage: { type: :number },
          included_in_price: { type: :boolean },
          show_rate_in_label: { type: :boolean },
          tax_category_id: { type: :string },
          country_code: { type: :string },
          state_code: { type: :string }
        }
      }

      response '200', 'tax rate updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { amount_percentage: 7 } }

        schema '$ref' => '#/components/schemas/TaxRate'

        run_test! do |response|
          expect(JSON.parse(response.body)['amount']).to eq('0.07')
        end
      end
    end

    delete 'Delete a tax rate' do
      tags 'Settings'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Soft-deletes the rate. Tax lines it already produced keep their own rate snapshot.'
      admin_scope :write, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '204', 'tax rate deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end
end
