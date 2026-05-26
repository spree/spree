# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Markets API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:country) { create(:country, iso: 'DE', iso3: 'DEU', name: 'Germany') }
  let!(:other_country) { create(:country, iso: 'FR', iso3: 'FRA', name: 'France') }
  let!(:market) { create(:market, store: store, name: 'EU', countries: [country]) }

  # `Spree::MarketCountry` validates that the country is covered by a shipping
  # zone with an active shipping method (see `country_covered_by_shipping_zone`).
  # The market factory does this for its own countries; we mirror that for the
  # other countries this spec assigns directly through the API.
  before do
    shipping_zone = Spree::Zone.find_or_create_by!(name: 'Test Shipping Zone') { |z| z.kind = 'country' }
    [country, other_country].each do |c|
      shipping_zone.zone_members.find_or_create_by!(zoneable: c)
    end
    if shipping_zone.shipping_methods.empty?
      shipping_category = Spree::ShippingCategory.first || create(:shipping_category)
      create(:shipping_method, zones: [shipping_zone], shipping_categories: [shipping_category])
    end
  end

  path '/api/v3/admin/markets' do
    get 'List markets' do
      tags 'Pricing'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns the markets configured for the current store. Markets are
        store-scoped and ordered by `position` (an `acts_as_list` column —
        update the order via `PATCH /markets/{id}` with `position`).
      DESC
      admin_scope :read, :settings

      admin_sdk_example 'markets/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :limit, in: :query, type: :integer, required: false
      parameter name: :'q[name_cont]', in: :query, type: :string, required: false
      parameter name: :sort, in: :query, type: :string, required: false
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to embed. Supported: `countries`.'

      response '200', 'markets found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('Market')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(market.prefixed_id)
        end
      end
    end

    post 'Create a market' do
      tags 'Pricing'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Creates a new market for the current store.

        - `country_isos` accepts 2-letter ISO country codes (e.g. `["DE", "FR"]`);
          the market must contain at least one country. Unknown codes are
          silently dropped.
        - `supported_locales` accepts an array of locale codes; the
          `default_locale` is always implicitly included.
        - Setting `default: true` automatically demotes the previous default
          market in the store.
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'markets/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Europe' },
          currency: { type: :string, example: 'EUR', description: 'ISO 4217 currency code.' },
          default_locale: { type: :string, example: 'de', description: 'IETF locale tag used as the market default.' },
          supported_locales: {
            type: :array,
            items: { type: :string },
            description: 'Locale codes available in this market. The default is always implicitly included.',
            example: %w[de en]
          },
          tax_inclusive: { type: :boolean, default: false, description: 'Display prices with tax included.' },
          default: { type: :boolean, default: false, description: 'Setting to true demotes the previous default.' },
          position: { type: :integer, description: 'Sort order within the store; lower = first.' },
          country_isos: {
            type: :array,
            items: { type: :string },
            description: '2-letter ISO country codes assigned to this market. At least one is required.',
            example: %w[DE FR]
          }
        },
        required: %w[name currency default_locale country_isos]
      }

      response '201', 'market created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          {
            name: 'France only',
            currency: 'EUR',
            default_locale: 'fr',
            supported_locales: ['fr', 'en'],
            tax_inclusive: true,
            country_isos: [other_country.iso]
          }
        end

        schema '$ref' => '#/components/schemas/Market'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('France only')
          expect(data['currency']).to eq('EUR')
          expect(data['tax_inclusive']).to be true
          expect(data['supported_locales']).to match_array(%w[en fr])
          expect(data['country_isos']).to eq(['FR'])
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/markets/{id}' do
    parameter name: :id, in: :path, type: :string, required: true

    get 'Get a market' do
      tags 'Pricing'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :settings

      admin_sdk_example 'markets/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false

      response '200', 'market found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { market.prefixed_id }

        schema '$ref' => '#/components/schemas/Market'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(market.prefixed_id)
        end
      end

      response '404', 'market not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'market_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a market' do
      tags 'Pricing'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Updates an existing market. Pass `country_isos` to replace the
        market's country list (full-set update), `supported_locales` to
        replace the supported locales, or `position` to reorder the market
        within the store.

        Setting `default: true` automatically demotes the previous default.
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'markets/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          currency: { type: :string },
          default_locale: { type: :string },
          supported_locales: { type: :array, items: { type: :string } },
          tax_inclusive: { type: :boolean },
          default: { type: :boolean },
          position: { type: :integer },
          country_isos: { type: :array, items: { type: :string } }
        }
      }

      response '200', 'market updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { market.prefixed_id }
        let(:body) { { name: 'European Union', tax_inclusive: true } }

        schema '$ref' => '#/components/schemas/Market'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('European Union')
          expect(data['tax_inclusive']).to be true
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { market.prefixed_id }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    delete 'Delete a market' do
      tags 'Pricing'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Soft-deletes the market (sets `deleted_at`). The default market and
        the last remaining market in a store cannot be deleted — both return
        422 with a `validation_error`.
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'markets/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'market deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        # Create a second market so the target isn't the last one in the store.
        let!(:second_market) { create(:market, store: store, name: 'ROW', countries: [other_country]) }
        let(:id) { market.prefixed_id }

        run_test!
      end

      response '422', 'cannot delete default or last market' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { market.prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
