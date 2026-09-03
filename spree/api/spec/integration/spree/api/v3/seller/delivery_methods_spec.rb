# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Delivery Methods API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let(:seller_role) do
    create(:role, name: 'Seller', resource: seller, permissions: %w[read_products write_delivery_methods])
  end

  let!(:delivery_profile) { create(:delivery_profile, store: store, name: 'Parcel') }
  let!(:own_method) { create(:delivery_method, store: store, seller: seller, name: 'My courier') }
  let!(:shared_method) { create(:delivery_method, store: store, available_to_sellers: true, name: 'Marketplace post') }

  path '/api/v3/seller/delivery_methods' do
    get 'List delivery methods' do
      tags 'Delivery Methods'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        How this seller's goods can ship: the methods they created themselves,
        plus any the marketplace shares with its sellers.

        A shared marketplace method comes back with `editable: false` — it is
        listed so the seller can see what already ships their goods, and every
        write against it is a 404.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'

      response '200', 'delivery methods listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/DeliveryMethod' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |item| item['id'] }).to contain_exactly(own_method.prefixed_id, shared_method.prefixed_id)
        end
      end
    end

    post 'Create a delivery method' do
      tags 'Delivery Methods'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Adds a way for this seller to ship. The method is always the seller's
        own, whatever the payload says.

        Neither the rate provider nor the fulfillment provider is settable: a
        seller prices their own rates and enters tracking numbers by hand,
        because carrier accounts belong to the marketplace.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          admin_name: { type: :string, nullable: true },
          code: { type: :string, nullable: true },
          delivery_profile_id: { type: :string, description: "One of the marketplace's delivery profiles" },
          delivery_zone_id: { type: :string, nullable: true, description: 'Narrows where the method ships' },
          storefront_visible: { type: :boolean },
          tracking_url: { type: :string, nullable: true },
          estimated_transit_business_days_min: { type: :integer, nullable: true },
          estimated_transit_business_days_max: { type: :integer, nullable: true },
          calculator_type: { type: :string },
          calculator_preferences: { type: :object },
          rules: {
            type: :array,
            description: 'Conditions on the method, from `/delivery_methods/rule_types`',
            items: {
              type: :object,
              properties: {
                type: { type: :string },
                preferences: { type: :object }
              }
            }
          }
        },
        required: %w[name]
      }

      response '201', 'delivery method created' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) do
          {
            name: 'Next day',
            delivery_profile_id: delivery_profile.prefixed_id,
            calculator_type: 'Spree::Calculator::Shipping::FlatRate',
            calculator_preferences: { amount: '9.99', currency: 'USD' }
          }
        end

        schema '$ref' => '#/components/schemas/DeliveryMethod'

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('Next day')
        end
      end

      response '422', 'invalid request' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/seller/delivery_methods/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Delivery method ID'
    parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

    get 'Retrieve a delivery method' do
      tags 'Delivery Methods'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'delivery method found' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { own_method.prefixed_id }

        schema '$ref' => '#/components/schemas/DeliveryMethod'

        run_test!
      end
    end

    patch 'Update a delivery method' do
      tags 'Delivery Methods'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Only the seller's own methods can be changed — a marketplace method shared with sellers is read-only."

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          admin_name: { type: :string, nullable: true },
          code: { type: :string, nullable: true },
          delivery_profile_id: { type: :string, description: "One of the marketplace's delivery profiles" },
          delivery_zone_id: { type: :string, nullable: true, description: 'Narrows where the method ships' },
          storefront_visible: { type: :boolean },
          tracking_url: { type: :string, nullable: true },
          estimated_transit_business_days_min: { type: :integer, nullable: true },
          estimated_transit_business_days_max: { type: :integer, nullable: true },
          calculator_type: { type: :string },
          calculator_preferences: { type: :object },
          rules: {
            type: :array,
            description: 'Replaces the whole set — a rule dropped here is deleted, so re-send surviving rules with their `id`.',
            items: {
              type: :object,
              properties: {
                id: { type: :string },
                type: { type: :string },
                preferences: { type: :object }
              }
            }
          }
        }
      }

      response '200', 'delivery method updated' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { own_method.prefixed_id }
        let(:body) { { name: 'My express courier' } }

        schema '$ref' => '#/components/schemas/DeliveryMethod'

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('My express courier')
        end
      end
    end

    delete 'Retire a delivery method' do
      tags 'Delivery Methods'
      security [bearer_auth: []]

      response '204', 'delivery method retired' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { own_method.prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/seller/delivery_methods/rule_types' do
    get 'List the conditions a method can carry' do
      tags 'Delivery Methods'
      produces 'application/json'
      security [bearer_auth: []]
      description 'The eligibility rules a seller may put on their own method, with the preference schema each form is rendered from.'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'rule types listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       type: { type: :string },
                       name: { type: :string },
                       description: { type: :string },
                       preference_schema: { type: :array, items: { type: :object } }
                     }
                   }
                 }
               },
               required: %w[data]

        run_test!
      end
    end
  end

  path '/api/v3/seller/delivery_methods/calculators' do
    get 'List the ways a method can be priced' do
      tags 'Delivery Methods'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'calculators listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       type: { type: :string },
                       name: { type: :string },
                       preference_schema: { type: :array, items: { type: :object } }
                     }
                   }
                 }
               },
               required: %w[data]

        run_test!
      end
    end
  end
end
