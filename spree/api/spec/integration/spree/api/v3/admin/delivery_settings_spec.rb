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
        properties: {
          name: { type: :string, example: 'Express' },
          admin_name: { type: :string, nullable: true },
          code: { type: :string, nullable: true },
          fulfillment_provider: { type: :string, nullable: true, example: 'Spree::FulfillmentProvider::Manual' },
          delivery_profile_id: { type: :string, nullable: true, example: 'fp_86Rf07xd4z' },
          storefront_visible: { type: :boolean, example: true },
          tracking_url: { type: :string, nullable: true },
          estimated_transit_business_days_min: { type: :integer, nullable: true },
          estimated_transit_business_days_max: { type: :integer, nullable: true },
          tax_category_id: { type: :string, nullable: true },
          calculator_type: { type: :string, example: 'Spree::Calculator::Shipping::FlatRate' },
          calculator_preferences: { type: :object, example: { amount: 12.5 } },
          delivery_zone_id: { type: :string, nullable: true }
        },
        required: %w[name]
      }

      response '201', 'delivery method created' do
        let(:body) do
          {
            name: 'Express',
            storefront_visible: true,
            calculator_type: 'Spree::Calculator::Shipping::FlatRate',
            calculator_preferences: { amount: 12.5 }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Express')
          expect(data['calculator_type']).to eq('Spree::Calculator::Shipping::FlatRate')
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
          expect(data['data'].map { |row| row['type'] }).to include('Spree::Calculator::Shipping::FlatRate')
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
        properties: {
          name: { type: :string, example: 'US North-East' },
          description: { type: :string, nullable: true },
          members: {
            type: :array,
            items: {
              type: :object,
              properties: {
                member_type: { type: :string, enum: %w[country state postal_code] },
                country_iso: { type: :string, nullable: true, example: 'US' },
                state_abbr: { type: :string, nullable: true },
                postal_code_prefix: { type: :string, nullable: true },
                postal_code_from: { type: :string, nullable: true },
                postal_code_to: { type: :string, nullable: true }
              },
              required: %w[member_type]
            }
          }
        },
        required: %w[name]
      }

      response '201', 'delivery zone created' do
        before { Spree::Country.by_iso('US') }

        let(:expand) { 'members' }
        let(:body) do
          {
            name: 'US North-East',
            members: [
              { member_type: 'country', country_iso: 'US' },
              { member_type: 'postal_code', country_iso: 'US', postal_code_prefix: '10' }
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
end
