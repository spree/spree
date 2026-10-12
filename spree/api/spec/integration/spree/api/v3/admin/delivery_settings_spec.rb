# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Delivery Settings API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }

  path '/api/v3/admin/delivery_methods' do
    get 'List delivery methods' do
      tags 'Delivery'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all delivery methods with calculator and zone configuration.'
      admin_scope :read, :settings

      admin_sdk_example 'delivery-methods/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      filter_parameters_for

      response '200', 'delivery methods found' do
        before { create(:delivery_method, name: 'UPS Ground') }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].map { |row| row['name'] }).to include('UPS Ground')
        end
      end
    end

    post 'Create delivery method' do
      tags 'Delivery'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a delivery method inside a delivery profile (defaults to the store default profile). Delivery behavior comes from the fulfillment provider.'
      admin_scope :write, :settings

      admin_sdk_example 'delivery-methods/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      request_body_for

      response '201', 'delivery method created' do
        let(:body) do
          {
            name: 'Express',
            storefront_visible: true,
            calculator: { type: 'flat_rate', preferences: { amount: '12.5' } }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Express')
          expect(data['calculator']['type']).to eq('flat_rate')
        end
      end
    end
  end

  path '/api/v3/admin/delivery_methods/{id}' do
    let(:delivery_method) { create(:delivery_method, name: 'UPS Ground') }
    let(:id) { delivery_method.prefixed_id }

    patch 'Update delivery method' do
      tags 'Delivery'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a delivery method. Only the attributes sent change.'
      admin_scope :write, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      request_body_for

      response '200', 'delivery method updated' do
        let(:body) { { name: 'UPS Express', estimated_transit_business_days_min: 1, estimated_transit_business_days_max: 2 } }

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('UPS Express')
        end
      end
    end
  end

  path '/api/v3/admin/delivery_methods/calculators' do
    get 'List delivery calculators' do
      tags 'Delivery'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Registered delivery calculator classes with preference schemas for building configuration forms.'
      admin_scope :write, :settings

      admin_sdk_example 'delivery-methods/calculators'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'calculators found' do
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].map { |row| row['type'] }).to include('flat_rate')
        end
      end
    end
  end

  path '/api/v3/admin/delivery_zones' do
    get 'List delivery zones' do
      tags 'Delivery'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the areas delivery methods ship to, each made of countries, states or postal code ranges.'
      admin_scope :read, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      filter_parameters_for

      response '200', 'delivery zones found' do
        let!(:delivery_zone) { create(:delivery_zone, store: store, name: 'US North-East') }

        schema SwaggerSchemaHelpers.paginated('DeliveryZone')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(delivery_zone.prefixed_id)
        end
      end
    end

    post 'Create delivery zone' do
      tags 'Delivery'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a delivery zone with typed members: country, state, or postal_code (prefix or from/to range).'
      admin_scope :write, :settings

      admin_sdk_example 'delivery-zones/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to embed, e.g. `members`'
      request_body_for

      response '201', 'delivery zone created' do
        before { Spree::Country.by_iso('US') }

        let(:expand) { 'members' }
        let(:body) do
          {
            name: 'US North-East',
            members: [
              { member_type: 'country', country_code: 'US' },
              { member_type: 'postal_code', country_code: 'US', postal_code_prefix: '10' }
            ]
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['members'].length).to eq(2)
        end
      end
    end
  end

  path '/api/v3/admin/delivery_zones/{id}' do
    let(:delivery_zone) { create(:delivery_zone, store: store, name: 'US North-East') }
    let(:id) { delivery_zone.prefixed_id }

    patch 'Update delivery zone' do
      tags 'Delivery'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a delivery zone. Sending `members` replaces the whole member list; leaving it out keeps the current members.'
      admin_scope :write, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to embed, e.g. `members`'
      request_body_for

      response '200', 'delivery zone updated' do
        before { Spree::Country.by_iso('US') }

        let(:expand) { 'members' }
        let(:body) do
          {
            name: 'US East Coast',
            members: [{ member_type: 'postal_code', country_code: 'US', postal_code_from: '10000', postal_code_to: '14999' }]
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('US East Coast')
          expect(data['members'].length).to eq(1)
        end
      end
    end
  end

  path '/api/v3/admin/delivery_methods/{delivery_method_id}/rules' do
    let(:delivery_method) { create(:delivery_method) }
    let(:delivery_method_id) { delivery_method.prefixed_id }

    get 'List delivery method rules' do
      tags 'Delivery'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the conditions a delivery method must meet to be offered at checkout, such as an order total or weight range.'
      admin_scope :read, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :delivery_method_id, in: :path, type: :string, required: true
      filter_parameters_for

      response '200', 'rules found' do
        let!(:rule) do
          Spree::DeliveryMethodRules::ItemTotalRule.create!(delivery_method: delivery_method, preferred_minimum_amount: '25')
        end

        schema SwaggerSchemaHelpers.paginated('DeliveryMethodRule')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(rule.prefixed_id)
        end
      end
    end

    post 'Create a delivery method rule' do
      tags 'Delivery'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Adds a condition to a delivery method. `type` is a rule kind from the
        delivery method rule types endpoint, and `preferences` takes the
        values its schema declares.
      DESC
      admin_scope :write, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :delivery_method_id, in: :path, type: :string, required: true
      request_body_for

      response '201', 'rule created' do
        let(:body) { { type: 'item_total_rule', preferences: { minimum_amount: '50.00' } } }

        schema '$ref' => '#/components/schemas/DeliveryMethodRule'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['type']).to eq('item_total_rule')
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

  path '/api/v3/admin/delivery_methods/{delivery_method_id}/rules/{id}' do
    let(:delivery_method) { create(:delivery_method) }
    let(:delivery_method_id) { delivery_method.prefixed_id }
    let(:rule) do
      Spree::DeliveryMethodRules::ItemTotalRule.create!(delivery_method: delivery_method, preferred_minimum_amount: '25')
    end
    let(:id) { rule.prefixed_id }

    patch 'Update a delivery method rule' do
      tags 'Delivery'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description "Changes a rule's settings or turns it off. Its `type` is fixed once created."
      admin_scope :write, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :delivery_method_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      request_body_for

      response '200', 'rule updated' do
        let(:body) { { active: false, preferences: { minimum_amount: '40.00', maximum_amount: '500.00' } } }

        schema '$ref' => '#/components/schemas/DeliveryMethodRule'

        run_test! do |response|
          expect(JSON.parse(response.body)['active']).to be(false)
          expect(rule.reload.preferred_maximum_amount.to_d).to eq(BigDecimal('500'))
        end
      end
    end
  end
end
