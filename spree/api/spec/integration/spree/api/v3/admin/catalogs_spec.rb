# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Catalogs API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:catalog) { create(:catalog, store: store, name: 'Wholesale') }

  path '/api/v3/admin/catalogs' do
    get 'List catalogs' do
      tags 'Catalogs'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the store catalogs — product assortments with an optional price list, shown to audiences through assignments.'
      admin_scope :read, :products

      admin_sdk_example 'catalogs/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'catalogs found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(catalog.prefixed_id)
        end
      end
    end

    post 'Create a catalog' do
      tags 'Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a catalog. Add products and assign audiences (customer group, or company subtree) afterwards.'
      admin_scope :write, :products

      admin_sdk_example 'catalogs/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'VIP Assortment' },
          active: { type: :boolean, example: true },
          price_list: { type: :object, nullable: true,
                        description: 'The price list this catalog owns, written inline. Omit for assortment-only (base prices); send null to remove the pricing, which deletes the list. A catalog with an empty assortment prices without restricting visibility; import or curate products to make it restrictive.',
                        properties: {
                          price_adjustment_percentage: { type: :string, nullable: true, example: '-15.0' },
                          adjust_compare_at: { type: :boolean, example: false }
                        } }
        },
        required: ['name']
      }

      let(:'x-spree-api-key') { secret_api_key.plaintext_token }

      response '201', 'catalog created' do
        let(:body) { { name: 'VIP Assortment' } }

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('VIP Assortment')
        end
      end

      response '422', 'invalid request' do
        let(:body) { { active: true } }

        run_test!
      end
    end
  end

  path '/api/v3/admin/catalogs/{id}/assign' do
    post 'Assign a catalog to an audience' do
      tags 'Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Shows the catalog to an audience. A company assignment covers the node and its whole subtree.'
      admin_scope :write, :products

      admin_sdk_example 'catalogs/assign'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          assignable_type: { type: :string, enum: %w[customer_group company],
                             example: 'company' },
          assignable_id: { type: :string, example: 'comp_86Rf07xd4z' }
        },
        required: %w[assignable_type assignable_id]
      }

      let(:'x-spree-api-key') { secret_api_key.plaintext_token }
      let(:id) { catalog.prefixed_id }

      response '201', 'catalog assigned' do
        let!(:company) { create(:company, store: store) }
        let(:body) { { assignable_type: 'company', assignable_id: company.prefixed_id } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['assignable_type']).to eq('company')
        end
      end
    end
  end
  path '/api/v3/admin/catalogs/{catalog_id}/products' do
    get 'List catalog products' do
      tags 'Catalogs'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description "The catalog's curated assortment, listed by product name — membership carries no order."
      admin_scope :read, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :catalog_id, in: :path, type: :string, required: true

      response '200', 'products found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:catalog_id) { catalog.prefixed_id }

        schema SwaggerSchemaHelpers.paginated('Product')

        run_test!
      end
    end

    post 'Add products to a catalog' do
      tags 'Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Curates products into the assortment in bulk. Already-present products are skipped; the count reports what was added.'
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :catalog_id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { product_ids: { type: :array, items: { type: :string }, example: ['prod_abc123'] } },
        required: %w[product_ids]
      }

      response '201', 'products added' do
        let!(:product) { create(:product, store: store) }
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:catalog_id) { catalog.prefixed_id }
        let(:body) { { product_ids: [product.prefixed_id] } }

        run_test! do |response|
          expect(JSON.parse(response.body)['added_count']).to eq(1)
        end
      end
    end

    delete 'Remove products from a catalog' do
      tags 'Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Removes products from the assortment in bulk. Ids that are not members are ignored; the count reports what was removed.'
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :catalog_id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { product_ids: { type: :array, items: { type: :string }, example: ['prod_abc123'] } },
        required: %w[product_ids]
      }

      response '200', 'products removed' do
        let!(:product) { create(:product, store: store) }
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:catalog_id) { catalog.prefixed_id }
        let(:body) { { product_ids: [product.prefixed_id] } }

        before { catalog.add_products([product.id]) }

        run_test! do |response|
          expect(JSON.parse(response.body)['removed_count']).to eq(1)
        end
      end
    end
  end

  path '/api/v3/admin/catalogs/{catalog_id}/quantity_rules' do
    get 'List catalog quantity rules' do
      tags 'Catalogs'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description "The catalog's per-variant quantity terms. The catalog-wide default is a pair of fields on the catalog itself, so these are strictly the overrides."
      admin_scope :read, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :catalog_id, in: :path, type: :string, required: true

      response '200', 'quantity rules found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:catalog_id) { catalog.prefixed_id }
        let!(:rule) do
          create(:catalog_quantity_rule, catalog: catalog,
                                         variant: create(:variant, product: create(:product, store: store)))
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(rule.prefixed_id)
        end
      end
    end

    post 'Create a catalog quantity rule' do
      tags 'Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'States how much of one variant a buyer on this agreement must order. Both fields are optional individually, but a rule must state at least one — a field left out falls through to the catalog default, and then to the variant.'
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :catalog_id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          variant_id: { type: :string, example: 'variant_86Rf07xd4z' },
          minimum_order_quantity: { type: :integer, nullable: true, example: 48,
                                    description: 'The least a buyer may order.' },
          order_multiple: { type: :integer, nullable: true, example: 24,
                            description: 'Orders must land on a multiple of this, counted from the minimum.' }
        },
        required: ['variant_id']
      }

      let(:'x-spree-api-key') { secret_api_key.plaintext_token }
      let(:catalog_id) { catalog.prefixed_id }
      let(:variant) { create(:variant, product: create(:product, store: store)) }

      response '201', 'quantity rule created' do
        let(:body) { { variant_id: variant.prefixed_id, minimum_order_quantity: 48, order_multiple: 24 } }

        run_test! do |response|
          expect(JSON.parse(response.body)['minimum_order_quantity']).to eq(48)
        end
      end

      response '422', 'invalid request' do
        let(:body) { { variant_id: variant.prefixed_id } }

        run_test!
      end
    end
  end

  path '/api/v3/admin/catalogs/{catalog_id}/order_minimums' do
    get 'List catalog order minimums' do
      tags 'Catalogs'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'The least a whole order must come to under this agreement. One row per currency — Spree holds no exchange rates, so a threshold is never stated once and converted.'
      admin_scope :read, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :catalog_id, in: :path, type: :string, required: true

      response '200', 'order minimums found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:catalog_id) { catalog.prefixed_id }
        let!(:minimum) { create(:catalog_order_minimum, catalog: catalog, currency: 'USD', amount: 500) }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('currency')).to include('USD')
        end
      end
    end

    post 'Create a catalog order minimum' do
      tags 'Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Requires orders in one currency to reach an amount. The buyer sees the shortfall on the cart while they can still act on it; completion is refused below it.'
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :catalog_id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          currency: { type: :string, example: 'USD' },
          amount: { type: :string, example: '500.00' }
        },
        required: %w[currency amount]
      }

      let(:'x-spree-api-key') { secret_api_key.plaintext_token }
      let(:catalog_id) { catalog.prefixed_id }

      response '201', 'order minimum created' do
        let(:body) { { currency: 'USD', amount: '500.00' } }

        run_test! do |response|
          expect(JSON.parse(response.body)['currency']).to eq('USD')
        end
      end

      response '422', 'invalid request' do
        let(:body) { { currency: 'USD', amount: '0' } }

        run_test!
      end
    end
  end

  path '/api/v3/admin/catalogs/{catalog_id}/quantity_rules/{id}' do
    patch 'Update a catalog quantity rule' do
      tags 'Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Restates one variant term. A field sent as null hands that field back to the catalog default; a rule must still state at least one of the two.'
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :catalog_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          minimum_order_quantity: { type: :integer, nullable: true, example: 96 },
          order_multiple: { type: :integer, nullable: true, example: 48 }
        }
      }

      response '200', 'quantity rule updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:catalog_id) { catalog.prefixed_id }
        let!(:quantity_rule) do
          create(:catalog_quantity_rule, catalog: catalog,
                                         variant: create(:variant, product: create(:product, store: store)))
        end
        let(:id) { quantity_rule.prefixed_id }
        let(:body) { { minimum_order_quantity: 96 } }

        run_test! do |response|
          expect(JSON.parse(response.body)['minimum_order_quantity']).to eq(96)
        end
      end
    end

    delete 'Delete a catalog quantity rule' do
      tags 'Catalogs'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description "Drops one variant's exception, so it falls back to the catalog's own default."
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :catalog_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '204', 'quantity rule deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:catalog_id) { catalog.prefixed_id }
        let!(:quantity_rule) do
          create(:catalog_quantity_rule, catalog: catalog,
                                         variant: create(:variant, product: create(:product, store: store)))
        end
        let(:id) { quantity_rule.prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/admin/catalogs/{catalog_id}/order_minimums/{id}' do
    patch 'Update a catalog order minimum' do
      tags 'Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description "Restates one currency's threshold."
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :catalog_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { amount: { type: :string, example: '750.00' } }
      }

      response '200', 'order minimum updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:catalog_id) { catalog.prefixed_id }
        let!(:order_minimum) { create(:catalog_order_minimum, catalog: catalog, currency: 'USD', amount: 500) }
        let(:id) { order_minimum.prefixed_id }
        let(:body) { { amount: '750.00' } }

        run_test! do |response|
          expect(JSON.parse(response.body)['amount']).to eq('750.0')
        end
      end
    end

    delete 'Delete a catalog order minimum' do
      tags 'Catalogs'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Lifts the threshold for one currency, so orders in it may come to any total.'
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :catalog_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '204', 'order minimum deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:catalog_id) { catalog.prefixed_id }
        let!(:order_minimum) { create(:catalog_order_minimum, catalog: catalog, currency: 'USD') }
        let(:id) { order_minimum.prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/admin/catalogs/{catalog_id}/product_terms' do
    get 'List catalog terms by product' do
      tags 'Catalogs'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description "The catalog's quantity terms at the grain a merchant states them: one entry per product, over rows the database keeps per variant. `mixed` marks a product whose variants carry different terms."
      admin_scope :read, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :catalog_id, in: :path, type: :string, required: true

      response '200', 'product terms found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:catalog_id) { catalog.prefixed_id }
        let!(:quantity_rule) do
          create(:catalog_quantity_rule, catalog: catalog,
                                         variant: create(:variant, product: create(:product, store: store)))
        end

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].first['minimum_order_quantity']).to eq(48)
        end
      end
    end

    put 'Set catalog terms by product' do
      tags 'Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Writes the given products\' terms in one request, keyed by prefixed product id. Both fields null clears that product\'s terms; a product not yet in the assortment is added, since a term with nothing to apply to is not a reachable state. Products absent from the payload are left alone — this is the one catalog-term surface that is not a whole-set replacement, because an agreement may name terms for thousands of SKUs.'
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :catalog_id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          terms: {
            type: :object,
            additionalProperties: {
              type: :object,
              properties: {
                minimum_order_quantity: { type: :integer, nullable: true, example: 48 },
                order_multiple: { type: :integer, nullable: true, example: 24 }
              }
            }
          }
        },
        required: ['terms']
      }

      response '200', 'product terms set' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:catalog_id) { catalog.prefixed_id }
        let(:product) { create(:product, store: store) }
        let(:body) do
          { terms: { product.prefixed_id => { minimum_order_quantity: 48, order_multiple: 24 } } }
        end

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].first['minimum_order_quantity']).to eq(48)
        end
      end
    end
  end

  path '/api/v3/admin/catalogs/{id}/activate' do
    parameter name: :id, in: :path, type: :string, required: true

    patch 'Activate a catalog' do
      tags 'Products'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Puts the agreement into effect: its audience starts seeing its
        assortment and paying its prices. Refused for a catalog nobody is
        assigned to, since activating it would reach no buyer — a channel's
        default catalog is reached through the channel instead, so it needs
        no assignment.
      DESC
      admin_scope :write, :products
      admin_sdk_example 'catalogs/activate'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'catalog activated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { catalog.prefixed_id }
        # Activation refuses an agreement nobody is assigned to; an audience
        # is what gives the shared fixture someone to apply to.
        before do
          create(:catalog_assignment, catalog: catalog, assignable: create(:company, store: store))
        end

        schema '$ref' => '#/components/schemas/Catalog'

        run_test! do |response|
          expect(JSON.parse(response.body)['active']).to be(true)
        end
      end
    end
  end

  path '/api/v3/admin/catalogs/{id}/deactivate' do
    parameter name: :id, in: :path, type: :string, required: true

    patch 'Deactivate a catalog' do
      tags 'Products'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Takes the agreement out of effect. Everything it holds — assignments,
        commercial terms, its price list — survives, so activating again
        resumes exactly what was there.
      DESC
      admin_scope :write, :products
      admin_sdk_example 'catalogs/deactivate'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'catalog deactivated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { catalog.prefixed_id }

        schema '$ref' => '#/components/schemas/Catalog'

        run_test! do |response|
          expect(JSON.parse(response.body)['active']).to be(false)
        end
      end
    end
  end

end
