# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Price Lists API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:price_list) { create(:price_list, store: store, name: 'Wholesale') }
  let!(:other_list) { create(:price_list, store: store, name: 'Holiday') }

  path '/api/v3/admin/price_lists' do
    get 'List price lists' do
      tags 'Pricing'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the price lists configured for the current store.'
      admin_scope :read, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :limit, in: :query, type: :integer, required: false
      parameter name: :'q[name_cont]', in: :query, type: :string, required: false
      parameter name: :'q[status_eq]', in: :query, type: :string, required: false
      parameter name: :sort, in: :query, type: :string, required: false
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to embed. Supported: `price_rules`.'

      response '200', 'price lists found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('PriceList')

        run_test! do |response|
          data = JSON.parse(response.body)
          ids = data['data'].pluck('id')
          expect(ids).to include(price_list.prefixed_id, other_list.prefixed_id)
        end
      end
    end

    post 'Create a price list' do
      tags 'Pricing'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a new draft price list.'
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[name],
        properties: {
          name: { type: :string, example: 'EU wholesale' },
          description: { type: :string, nullable: true },
          starts_at: { type: :string, nullable: true, example: '2026-06-01T00:00:00Z' },
          ends_at: { type: :string, nullable: true, example: '2026-09-01T00:00:00Z' },
          match_policy: { type: :string, enum: %w[all any], example: 'all' },
          position: { type: :integer, example: 1 },
          product_ids: {
            type: :array,
            items: { type: :string },
            description: 'Prefixed product ids to seed the list with.',
            example: ['prod_aBc123']
          },
          rules: {
            type: :array,
            description: 'STI-typed price rules to attach on create. Existing rules ' \
                         'on the same payload via PATCH reconcile by id.',
            items: {
              type: :object,
              required: %w[type],
              properties: {
                type: { type: :string, example: 'volume_rule' },
                preferences: { type: :object, additionalProperties: true }
              }
            }
          },
          prices: {
            type: :array,
            description: 'Server-to-server alternative to `product_ids`: ship the ' \
                         'exact per-variant prices the list should contain. Each row ' \
                         'upserts on the unique key `(variant_id, currency, price_list_id)`. ' \
                         'Mix-and-match with `product_ids` is supported but typically ' \
                         'unnecessary — `prices` alone tells the server which variants ' \
                         'belong to the list and what the override amount is.',
            items: {
              type: :object,
              required: %w[variant_id currency],
              properties: {
                variant_id: { type: :string, example: 'variant_xY9' },
                currency: { type: :string, example: 'USD' },
                amount: { type: :string, nullable: true, example: '19.99' },
                compare_at_amount: { type: :string, nullable: true, example: '24.99' }
              }
            }
          }
        }
      }

      response '201', 'price list created (one-shot — metadata, schedule, products, rules)' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product1) { create(:product, stores: [store]) }
        let(:product2) { create(:product, stores: [store]) }
        let(:customer_group) { create(:customer_group, store: store) }
        let(:body) do
          {
            name: 'EU wholesale',
            description: 'B2B verified customers',
            match_policy: 'all',
            starts_at: '2026-06-01T00:00:00Z',
            ends_at: '2026-09-01T00:00:00Z',
            product_ids: [product1.prefixed_id, product2.prefixed_id],
            rules: [
              {
                type: 'customer_group_rule',
                preferences: { customer_group_ids: [customer_group.prefixed_id] }
              },
              {
                type: 'volume_rule',
                preferences: { min_quantity: 10 }
              }
            ]
          }
        end

        schema '$ref' => '#/components/schemas/PriceList'

        run_test! do |response|
          data = JSON.parse(response.body)
          list = Spree::PriceList.for_store(store).find_by_prefix_id!(data['id'])
          expect(list.name).to eq('EU wholesale')
          expect(list.match_policy).to eq('all')
          expect(list.status).to eq('draft')
          expect(list.products).to contain_exactly(product1, product2)
          expect(list.price_rules.length).to eq(2)
          cg_rule = list.price_rules.find { |r| r.is_a?(Spree::PriceRules::CustomerGroupRule) }
          volume_rule = list.price_rules.find { |r| r.is_a?(Spree::PriceRules::VolumeRule) }
          # Preferences are normalized to string-coerced raw IDs by the
          # rule's `parse_on_set` decoder — prefixed `cg_…` IDs come in
          # off the wire and land as `customer_group.id.to_s` in storage.
          expect(cg_rule.preferred_customer_group_ids).to contain_exactly(customer_group.id.to_s)
          expect(volume_rule.preferred_min_quantity).to eq(10)
        end
      end

      response '201', 'price list created (server-to-server — rules + prices, no product_ids)' do
        # The natural API shape when you already know the exact per-variant
        # prices: skip `product_ids` and ship `prices` directly. Variants
        # referenced in `prices` implicitly become part of the list.
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product) { create(:product, stores: [store]) }
        let(:variant_a) { product.master }
        let(:variant_b) { create(:variant, product: product) }
        let(:body) do
          {
            name: 'EU wholesale',
            match_policy: 'all',
            rules: [
              { type: 'volume_rule', preferences: { min_quantity: 10 } }
            ],
            prices: [
              {
                variant_id: variant_a.prefixed_id,
                currency: 'USD',
                amount: '19.99',
                compare_at_amount: '24.99'
              },
              {
                variant_id: variant_b.prefixed_id,
                currency: 'USD',
                amount: '21.99'
              }
            ]
          }
        end

        schema '$ref' => '#/components/schemas/PriceList'

        run_test! do |response|
          data = JSON.parse(response.body)
          list = Spree::PriceList.for_store(store).find_by_prefix_id!(data['id'])

          # Two priced rows landed under this list.
          rows = list.prices.where(currency: 'USD').to_a
          a_row = rows.find { |r| r.variant_id == variant_a.id }
          b_row = rows.find { |r| r.variant_id == variant_b.id }
          expect(a_row.amount).to eq(BigDecimal('19.99'))
          expect(a_row.compare_at_amount).to eq(BigDecimal('24.99'))
          expect(b_row.amount).to eq(BigDecimal('21.99'))

          # The rule survived the same payload.
          expect(list.price_rules.length).to eq(1)
          expect(list.price_rules.first).to be_a(Spree::PriceRules::VolumeRule)
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

  path '/api/v3/admin/price_lists/{id}' do
    parameter name: :id, in: :path, type: :string, required: true

    get 'Get a price list' do
      tags 'Pricing'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false

      response '200', 'price list found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { price_list.prefixed_id }

        schema '$ref' => '#/components/schemas/PriceList'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(price_list.prefixed_id)
        end
      end

      response '404', 'price list not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'pl_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a price list' do
      tags 'Pricing'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Updates a price list. The optional `rules:` array reconciles nested
        STI-typed price rules in a single round-trip — existing rules update
        by `id`, new rules build, missing rules destroy. Mirrors the
        promotion editor's "save the whole thing on Save" pattern.
      DESC
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string, nullable: true },
          starts_at: { type: :string, nullable: true },
          ends_at: { type: :string, nullable: true },
          match_policy: { type: :string, enum: %w[all any] },
          position: { type: :integer },
          product_ids: {
            type: :array,
            items: { type: :string },
            description: 'Prefixed product ids — reconciles list membership (adds + removes).',
            example: ['prod_aBc123']
          },
          rules: {
            type: :array,
            items: {
              type: :object,
              required: %w[type],
              properties: {
                id: { type: :string, nullable: true },
                type: { type: :string, example: 'volume_rule' },
                preferences: { type: :object, additionalProperties: true }
              }
            }
          },
          prices: {
            type: :array,
            description: 'Individual price overrides (the spreadsheet payload). ' \
                         'Each row updates by `id` if shipped, otherwise upserts ' \
                         'on the unique key `(variant_id, currency, price_list_id)`.',
            items: {
              type: :object,
              oneOf: [
                { required: %w[id] },
                { required: %w[variant_id currency] }
              ],
              properties: {
                id: { type: :string, example: 'price_aBc123' },
                variant_id: { type: :string, example: 'variant_xY9' },
                currency: { type: :string, example: 'USD' },
                amount: { type: :string, nullable: true, example: '12.50' },
                compare_at_amount: { type: :string, nullable: true, example: '15.00' }
              }
            }
          }
        }
      }

      response '200', 'price list updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { price_list.prefixed_id }
        let(:body) { { name: 'Wholesale (Q3)' } }

        schema '$ref' => '#/components/schemas/PriceList'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Wholesale (Q3)')
        end
      end

      response '200', 'price list membership reconciles via product_ids' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { price_list.prefixed_id }
        let(:kept_product) { create(:product, stores: [store]) }
        let(:removed_product) { create(:product, stores: [store]) }
        let(:added_product) { create(:product, stores: [store]) }
        let(:body) { { product_ids: [kept_product.prefixed_id, added_product.prefixed_id] } }

        before do
          # Seed the list with kept + removed; PATCH should drop `removed`
          # and pick up `added` in a single round-trip.
          price_list.add_products([kept_product.id, removed_product.id])
        end

        schema '$ref' => '#/components/schemas/PriceList'

        run_test! do
          products = price_list.reload.products
          expect(products).to include(kept_product, added_product)
          expect(products).not_to include(removed_product)
        end
      end

      response '200', 'price overrides reconcile via prices' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { price_list.prefixed_id }
        let(:product) { create(:product, stores: [store]) }
        let(:variant) { product.master }
        let!(:placeholder) do
          create(:price, variant: variant, price_list: price_list, currency: 'USD', amount: nil)
        end
        let(:body) do
          {
            prices: [
              {
                variant_id: variant.prefixed_id,
                currency: 'USD',
                amount: '19.99',
                compare_at_amount: '24.99'
              }
            ]
          }
        end

        schema '$ref' => '#/components/schemas/PriceList'

        run_test! do
          rows = Spree::Price.where(
            variant_id: variant.id, currency: 'USD', price_list_id: price_list.id
          )
          expect(rows.count).to eq(1)
          expect(rows.first.amount).to eq(BigDecimal('19.99'))
          expect(rows.first.compare_at_amount).to eq(BigDecimal('24.99'))
        end
      end

      response '200', 'price list updated with nested rules' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { price_list.prefixed_id }
        let(:body) do
          {
            name: 'Wholesale (Q3)',
            rules: [
              { type: 'volume_rule', preferences: { min_quantity: 25 } }
            ]
          }
        end

        schema '$ref' => '#/components/schemas/PriceList'

        run_test! do
          rules = price_list.reload.price_rules
          expect(rules.length).to eq(1)
          expect(rules.first).to be_a(Spree::PriceRules::VolumeRule)
          expect(rules.first.preferred_min_quantity).to eq(25)
        end
      end
    end

    delete 'Delete a price list' do
      tags 'Pricing'
      security [api_key: [], bearer_auth: []]
      description 'Soft-deletes the price list. Associated prices are removed asynchronously.'
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'price list deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { price_list.prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/admin/price_lists/{id}/activate' do
    parameter name: :id, in: :path, type: :string, required: true

    patch 'Activate a price list' do
      tags 'Pricing'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Transitions a draft / inactive list to `active`. If `starts_at` is
        in the future the list is marked `scheduled` instead, matching the
        legacy admin behaviour.
      DESC
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'price list activated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { price_list.prefixed_id }

        schema '$ref' => '#/components/schemas/PriceList'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('active')
        end
      end
    end
  end

  path '/api/v3/admin/price_lists/{id}/deactivate' do
    parameter name: :id, in: :path, type: :string, required: true

    patch 'Deactivate a price list' do
      tags 'Pricing'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'price list deactivated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:price_list) { create(:price_list, :active, store: store) }
        let(:id) { price_list.prefixed_id }

        schema '$ref' => '#/components/schemas/PriceList'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('inactive')
        end
      end
    end
  end

end
