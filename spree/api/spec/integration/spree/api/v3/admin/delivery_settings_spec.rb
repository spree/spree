# frozen_string_literal: true

require 'swagger_helper'

# Create and update accept the same attributes, so each resource documents one shape.
DELIVERY_METHOD_WRITE_PROPERTIES = {
  name: { type: :string, example: 'Express' },
  admin_name: { type: :string, nullable: true },
  code: { type: :string, nullable: true },
  fulfillment_provider: { type: :string, nullable: true, example: 'Spree::FulfillmentProvider::Manual',
                          description: 'A provider from `GET /delivery_methods/fulfillment_providers`.' },
  rate_provider: { type: :string, nullable: true, example: 'Spree::DeliveryRateProvider::Internal',
                   description: 'A provider from `GET /delivery_methods/rate_providers`. Blank uses the internal calculator.' },
  pickup_point_provider: { type: :string, nullable: true },
  delivery_profile_id: { type: :string, nullable: true, example: 'fp_86Rf07xd4z' },
  delivery_origin_group_id: { type: :string, nullable: true },
  delivery_zone_id: { type: :string, nullable: true },
  storefront_visible: { type: :boolean, example: true },
  available_to_sellers: { type: :boolean },
  tracking_url: { type: :string, nullable: true },
  estimated_transit_business_days_min: { type: :integer, nullable: true },
  estimated_transit_business_days_max: { type: :integer, nullable: true },
  tax_category_id: { type: :string, nullable: true },
  calculator_type: { type: :string, example: 'flat_rate' },
  calculator_preferences: { type: :object, example: { amount: 12.5 } },
  markup_flat: { type: :number, description: 'Handling fee added to every provider quote.' },
  markup_percent: { type: :number, description: 'Percentage added to every provider quote.' },
  stock_location_ids: { type: :array, items: { type: :string },
                        description: 'Pickup locations for a pickup method. Replaces the full set.' },
  rules: {
    type: :array,
    description: 'Eligibility rules. What you send replaces what the method holds.',
    items: {
      type: :object,
      properties: {
        id: { type: :string, description: 'Present for an existing rule; omit to create one.' },
        type: { type: :string, example: 'weight_rule',
                description: 'channel_rule, company_rule, excluded_products_rule, item_total_rule, volume_rule, weight_rule, or a registered extension kind.' },
        active: { type: :boolean },
        preferences: { type: :object },
        product_ids: { type: :array, items: { type: :string },
                       description: 'For kinds that name products, which are kept outside preferences.' }
      }
    }
  },
  services: {
    type: :array,
    description: 'Carrier services offered by a provider-priced method. What you send replaces what the method holds.',
    items: {
      type: :object,
      properties: {
        id: { type: :string },
        carrier: { type: :string, example: 'UPS' },
        service: { type: :string, example: 'Ground' },
        label: { type: :string, nullable: true },
        markup_flat: { type: :number, nullable: true },
        markup_percent: { type: :number, nullable: true },
        position: { type: :integer }
      }
    }
  }
}.freeze

DELIVERY_ZONE_WRITE_PROPERTIES = {
  name: { type: :string, example: 'US North-East' },
  description: { type: :string, nullable: true },
  delivery_profile_id: { type: :string, nullable: true, description: 'Defaults to the store default profile.' },
  delivery_origin_group_id: { type: :string, nullable: true },
  members: {
    type: :array,
    description: 'Replaces the full member set.',
    items: {
      type: :object,
      properties: {
        member_type: { type: :string, enum: %w[country state postal_code] },
        country_code: { type: :string, nullable: true, example: 'US' },
        state_code: { type: :string, nullable: true },
        postal_code_prefix: { type: :string, nullable: true },
        postal_code_from: { type: :string, nullable: true },
        postal_code_to: { type: :string, nullable: true }
      },
      required: %w[member_type]
    }
  }
}.freeze

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

      response '200', 'delivery methods found' do
        before { create(:shipping_method, name: 'UPS Ground') }

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
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: DELIVERY_METHOD_WRITE_PROPERTIES,
        required: %w[name]
      }

      response '201', 'delivery method created' do
        let(:body) do
          {
            name: 'Express',
            storefront_visible: true,
            calculator_type: 'flat_rate',
            calculator_preferences: { amount: 12.5 }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Express')
          expect(data['calculator_type']).to eq('flat_rate')
        end
      end
    end
  end

  path '/api/v3/admin/delivery_methods/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Delivery method ID'

    patch 'Update delivery method' do
      tags 'Delivery'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a delivery method. Sending `rules` or `services` replaces the full set.'
      admin_scope :write, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: DELIVERY_METHOD_WRITE_PROPERTIES
      }

      response '200', 'delivery method updated' do
        let(:delivery_method) { create(:shipping_method, name: 'UPS Ground') }
        let(:id) { delivery_method.prefixed_id }
        let(:body) { { name: 'UPS Ground (Updated)', estimated_transit_business_days_max: 5 } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('UPS Ground (Updated)')
          expect(delivery_method.reload.estimated_transit_business_days_max).to eq(5)
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
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: DELIVERY_ZONE_WRITE_PROPERTIES,
        required: %w[name]
      }

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
    parameter name: :id, in: :path, type: :string, required: true, description: 'Delivery zone ID'

    patch 'Update delivery zone' do
      tags 'Delivery'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a delivery zone. Sending `members` replaces the full member set.'
      admin_scope :write, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to embed, e.g. `members`'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: DELIVERY_ZONE_WRITE_PROPERTIES
      }

      response '200', 'delivery zone updated' do
        before { Spree::Country.by_iso('US') }

        let(:zone) { create(:delivery_zone, store: store, name: 'East Coast') }
        let(:id) { zone.prefixed_id }
        let(:expand) { 'members' }
        let(:body) do
          {
            name: 'US East Coast',
            members: [{ member_type: 'country', country_code: 'US' }]
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
end
