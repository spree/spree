# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Payment Methods API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:payment_method) { create(:check_payment_method) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/payment_methods' do
    get 'List payment methods' do
      tags 'Payment Methods'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the store\'s configured payment methods. Use `source_required: true` to know which methods need a saved source.'
      admin_scope :read, :settings

      admin_sdk_example 'payment-methods/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand. Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,type,active). id is always included.'
      filter_parameters_for

      response '200', 'payment methods found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end
    post 'Create a payment method' do
      tags 'Payment Methods'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Adds a payment method to the store. `type` is a shorthand from the
        payment method types endpoint, and `preferences` takes the values its
        preference schema declares (gateway credentials among them).
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'payment-methods/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      request_body_for

      response '201', 'payment method created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          {
            type: 'check',
            name: 'Bank transfer',
            description: 'Pay by bank transfer within 14 days.',
            active: true,
            storefront_visible: true,
            capture_method: 'manual'
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['type']).to eq('check')
          expect(data['name']).to eq('Bank transfer')
        end
      end

      response '422', 'unknown payment method type' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { type: 'not_a_provider', name: 'Mystery' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/payment_methods/types' do
    get 'List available payment provider types' do
      tags 'Payment Methods'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns every registered payment provider with the JSON Schema of its `preferences`. `installed_count` is how many payment methods of that provider the store already has; a store may run several, one per provider account, each scoped with rules. `installed` is deprecated: use `installed_count`. Removed in 6.2.'
      admin_scope :read, :settings

      admin_sdk_example 'payment-methods/types'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'provider types found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       type: { type: :string },
                       label: { type: :string },
                       installed_count: { type: :integer, description: 'How many payment methods of this provider the store has.' },
                       installed: { type: :boolean, deprecated: true, description: 'Use installed_count. Removed in 6.2.' }
                     },
                     required: %w[type label installed_count]
                   }
                 }
               },
               required: %w[data]

        before do
          # Install StoreCredit in the store so the entry is marked installed.
          # (Check is also installed via the let!(:payment_method), but other
          # tests in this file delete it, so it's order-dependent.)
          store.payment_methods.create!(type: 'Spree::PaymentMethod::StoreCredit', name: 'Store Credit')
        end

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data).to be_an(Array)
          expect(data).to all(include('type', 'label'))
          installed = data.to_h { |entry| [entry['type'], entry['installed_count']] }
          expect(installed).to include('store_credit' => 1, 'bogus' => 0)
        end
      end
    end
  end

  path '/api/v3/admin/payment_methods/{id}' do
    let(:id) { payment_method.prefixed_id }

    get 'Show a payment method' do
      tags 'Payment Methods'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a payment method by ID.'
      admin_scope :read, :settings

      admin_sdk_example 'payment-methods/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand. Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,type,active). id is always included.'

      response '200', 'payment method found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(payment_method.prefixed_id)
        end
      end
    end

    patch 'Update a payment method' do
      tags 'Payment Methods'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a payment method. Its `type` is fixed once created.'
      admin_scope :write, :settings

      admin_sdk_example 'payment-methods/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      request_body_for

      response '200', 'payment method updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'Cheque', storefront_visible: false, position: 2 } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Cheque')
        end
      end
    end
  end

  path '/api/v3/admin/payment_methods/{payment_method_id}/rules' do
    let(:payment_method_id) { payment_method.prefixed_id }
    let(:'x-spree-api-key') { secret_api_key.plaintext_token }

    get 'List payment method rules' do
      tags 'Payment Methods'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the conditions a payment method must meet to be offered at storefront checkout, such as a channel, a market or an order total range. Every active rule must pass; a method with no rules is offered everywhere. Payments taken in the dashboard ignore rules.'
      admin_scope :read, :settings

      admin_sdk_example 'payment-methods/rules-list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :payment_method_id, in: :path, type: :string, required: true
      filter_parameters_for

      response '200', 'rules found' do
        let!(:rule) { create(:company_payment_method_rule, payment_method: payment_method) }

        schema SwaggerSchemaHelpers.paginated('PaymentMethodRule')

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].pluck('id')).to include(rule.prefixed_id)
        end
      end
    end

    post 'Create a payment method rule' do
      tags 'Payment Methods'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Adds a condition to a payment method. `type` is a rule kind from the
        payment method rule types endpoint, and `preferences` takes the values
        its schema declares. Each kind can appear once per method. To run two
        accounts of one provider, give each payment method a `market_rule`
        with its own markets.
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'payment-methods/rules-create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :payment_method_id, in: :path, type: :string, required: true
      request_body_for

      response '201', 'rule created' do
        let(:body) { { type: 'order_total_rule', preferences: { min_totals: { USD: '5000.00' } } } }

        schema '$ref' => '#/components/schemas/PaymentMethodRule'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['type']).to eq('order_total_rule')
          expect(data['active']).to be(true)
        end
      end

      response '422', 'unknown rule type' do
        let(:body) { { type: 'not_a_rule' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/payment_methods/{payment_method_id}/rules/{id}' do
    let(:payment_method_id) { payment_method.prefixed_id }
    let(:'x-spree-api-key') { secret_api_key.plaintext_token }
    let(:rule) { create(:company_payment_method_rule, payment_method: payment_method) }
    let(:id) { rule.prefixed_id }

    patch 'Update a payment method rule' do
      tags 'Payment Methods'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description "Changes a rule's settings or turns it off. Its `type` is fixed once created."
      admin_scope :write, :settings

      admin_sdk_example 'payment-methods/rules-update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :payment_method_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      request_body_for

      response '200', 'rule updated' do
        let(:body) { { active: false, preferences: { company_orders_only: false } } }

        schema '$ref' => '#/components/schemas/PaymentMethodRule'

        run_test! do |response|
          expect(JSON.parse(response.body)['active']).to be(false)
        end
      end
    end

    delete 'Delete a payment method rule' do
      tags 'Payment Methods'
      security [api_key: [], bearer_auth: []]
      description 'Removes a condition from a payment method.'
      admin_scope :write, :settings

      admin_sdk_example 'payment-methods/rules-delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :payment_method_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '204', 'rule deleted' do
        run_test!
      end
    end
  end

  path '/api/v3/admin/payment_method_rules/types' do
    get 'List available payment method rule types' do
      tags 'Payment Methods'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Enumerates the registered payment method rule kinds with their names, descriptions and preference schemas, for building an "Add condition" picker. Plugins extend the list by registering `Spree::PaymentMethodRule` subclasses in `Spree.payment_method_rules`.'
      admin_scope :read, :settings

      admin_sdk_example 'payment-methods/rule-types'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'types found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |type| type['type'] }).to include('channel_rule', 'market_rule', 'order_total_rule')
          expect(data.first).to include('label', 'description', 'schema')
        end
      end
    end
  end
end
