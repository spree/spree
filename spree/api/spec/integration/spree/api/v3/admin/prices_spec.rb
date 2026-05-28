# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Prices API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:price_list) { create(:price_list, store: store) }
  let(:product) { create(:product) }
  # Use a non-master variant from the start. Touching the master while
  # also creating sibling variants later in the example triggers the
  # `remove_prices_from_master_variant` callback (variant.rb), which
  # `delete_all`s the master's prices and would silently wipe our seed.
  let!(:variant) { create(:variant, product: product) }
  let!(:list_price) do
    create(:price, variant: variant, price_list: price_list, currency: 'USD', amount: 5.0)
  end
  let(:base_price) { variant.prices.find_by!(currency: 'USD', price_list_id: nil) }

  path '/api/v3/admin/prices' do
    get 'List prices' do
      tags 'Pricing'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Generic prices endpoint covering both base prices and price-list
        overrides. Filter with Ransack: `q[price_list_id_eq]=…`,
        `q[currency_eq]=USD`, `q[price_list_id_null]=true` (base prices only).

        The admin spreadsheet uses this with server-side pagination so it
        scales past the metadata-PATCH path on `/price_lists/:id`.
      DESC
      admin_scope :read, :products

      admin_sdk_example 'prices/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :limit, in: :query, type: :integer, required: false
      parameter name: :'q[price_list_id_eq]', in: :query, type: :string, required: false
      parameter name: :'q[price_list_id_null]', in: :query, type: :boolean, required: false
      parameter name: :'q[currency_eq]', in: :query, type: :string, required: false
      parameter name: :'q[variant_id_eq]', in: :query, type: :string, required: false
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Comma-separated sort keys. Supports e.g. `variant_product_name,variant_id`.'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to embed. Supported: `variant`.'

      response '200', 'prices found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('Price')

        run_test! do |response|
          data = JSON.parse(response.body)
          ids = data['data'].pluck('id')
          expect(ids).to include(base_price.prefixed_id, list_price.prefixed_id)
        end
      end
    end

    post 'Create a price' do
      tags 'Pricing'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Creates a single price. Omit `price_list_id` to create a base price.
        For more than a handful of rows, prefer `POST /admin/prices/bulk_upsert`.
      DESC
      admin_scope :write, :products

      admin_sdk_example 'prices/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[variant_id currency],
        properties: {
          variant_id: { type: :string, example: 'variant_xY9' },
          currency: { type: :string, example: 'USD' },
          amount: { type: :string, nullable: true, example: '19.99' },
          compare_at_amount: { type: :string, nullable: true, example: '24.99' },
          price_list_id: { type: :string, nullable: true, example: 'pl_aBc123' }
        }
      }

      response '201', 'price created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:other_variant) { create(:variant, product: product) }
        let(:body) do
          {
            variant_id: other_variant.prefixed_id,
            currency: 'EUR',
            amount: '9.99'
          }
        end

        schema '$ref' => '#/components/schemas/Price'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['currency']).to eq('EUR')
          expect(data['amount']).to eq('9.99')
        end
      end
    end
  end

  path '/api/v3/admin/prices/{id}' do
    parameter name: :id, in: :path, type: :string, required: true

    get 'Get a price' do
      tags 'Pricing'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :products

      admin_sdk_example 'prices/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'price found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { list_price.prefixed_id }

        schema '$ref' => '#/components/schemas/Price'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(list_price.prefixed_id)
        end
      end

      response '404', 'price not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'price_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a price' do
      tags 'Pricing'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :products

      admin_sdk_example 'prices/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          amount: { type: :string, nullable: true },
          compare_at_amount: { type: :string, nullable: true }
        }
      }

      response '200', 'price updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { list_price.prefixed_id }
        let(:body) { { amount: '12.34' } }

        schema '$ref' => '#/components/schemas/Price'

        run_test! do
          expect(list_price.reload.amount).to eq(BigDecimal('12.34'))
        end
      end
    end

    delete 'Delete a price' do
      tags 'Pricing'
      security [api_key: [], bearer_auth: []]
      description 'Soft-deletes the price (acts_as_paranoid).'
      admin_scope :write, :products

      admin_sdk_example 'prices/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'price deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { list_price.prefixed_id }

        run_test! do
          expect(list_price.reload.deleted_at).not_to be_nil
        end
      end
    end
  end

  path '/api/v3/admin/prices/bulk_upsert' do
    post 'Bulk-upsert prices' do
      tags 'Pricing'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Upserts a batch of prices in a single SQL round trip.

        Each row either:
        * targets an existing price by `id`, OR
        * matches on the unique key `(variant_id, currency, price_list_id)` —
          updating the existing row if one exists, creating one otherwise.

        Model callbacks (e.g. PriceHistory) are bypassed; this is a
        bulk-write fast path for the admin spreadsheet. The response
        carries `price_count` — the number of rows touched.
      DESC
      admin_scope :write, :products

      admin_sdk_example 'prices/bulk-upsert'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[prices],
        properties: {
          prices: {
            type: :array,
            items: {
              type: :object,
              required: %w[variant_id currency],
              properties: {
                id: { type: :string, nullable: true, example: 'price_aBc123' },
                variant_id: { type: :string, example: 'variant_xY9' },
                currency: { type: :string, example: 'USD' },
                price_list_id: { type: :string, nullable: true, example: 'pl_aBc123' },
                amount: { type: :string, nullable: true, example: '19.99' },
                compare_at_amount: { type: :string, nullable: true, example: '24.99' }
              }
            }
          }
        }
      }

      response '200', 'prices upserted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:other_variant) { create(:variant, product: product) }
        let(:body) do
          {
            prices: [
              # Update existing row via unique key
              {
                variant_id: variant.prefixed_id,
                currency: 'USD',
                price_list_id: price_list.prefixed_id,
                amount: '11.11'
              },
              # Insert new row via unique key
              {
                variant_id: other_variant.prefixed_id,
                currency: 'USD',
                price_list_id: price_list.prefixed_id,
                amount: '22.22'
              }
            ]
          }
        end

        schema type: :object, properties: {
          price_count: { type: :integer }
        }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to eq('price_count' => 2)
        end
      end

      response '422', 'missing prices key' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { {} }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/prices/bulk_destroy' do
    delete 'Bulk-delete prices' do
      tags 'Pricing'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Soft-deletes each price in `ids`. Returns the count actually destroyed.'
      admin_scope :write, :products

      admin_sdk_example 'prices/bulk-destroy'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[ids],
        properties: {
          ids: { type: :array, items: { type: :string } }
        }
      }

      response '200', 'prices deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { ids: [list_price.prefixed_id] } }

        schema type: :object, properties: {
          price_count: { type: :integer }
        }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to eq('price_count' => 1)
          expect(list_price.reload.deleted_at).not_to be_nil
        end
      end
    end
  end
end
