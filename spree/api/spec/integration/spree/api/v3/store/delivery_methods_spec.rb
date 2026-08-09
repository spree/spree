# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Store Delivery Methods API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:'x-spree-api-key') { api_key.token }

  path '/api/v3/store/delivery_methods' do
    get 'List delivery methods' do
      tags 'Delivery'
      produces 'application/json'
      security [api_key: []]
      description 'Storefront-visible delivery methods. Filter by fulfillment_type to discover pickup options.'

      sdk_example 'delivery-methods/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :fulfillment_type, in: :query, type: :string, required: false,
                description: 'Filter: shipping, digital, pickup'

      response '200', 'delivery methods found' do
        before do
          create(:shipping_method, name: 'Standard')
          create(:pickup_delivery_method, name: 'Store pickup')
        end

        let(:fulfillment_type) { 'pickup' }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].map { |row| row['name'] }).to eq(['Store pickup'])
        end
      end
    end
  end

  path '/api/v3/store/delivery_methods/{id}/pickup_locations' do
    get 'List pickup locations' do
      tags 'Delivery'
      produces 'application/json'
      security [api_key: []]
      description 'Pickup-enabled stock locations for a pickup delivery method. Pass cart_id to keep only locations that can fulfill the whole cart from local stock.'

      sdk_example 'delivery-methods/pickup-locations'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true, description: 'Delivery method prefixed ID'
      parameter name: :cart_id, in: :query, type: :string, required: false, description: 'Cart prefixed ID for availability filtering'

      response '200', 'pickup locations found' do
        let(:pickup_method) do
          create(:pickup_delivery_method, name: 'Store pickup')
        end
        let(:id) { pickup_method.prefixed_id }

        before { create(:stock_location, name: 'Downtown', pickup_enabled: true) }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].map { |row| row['name'] }).to include('Downtown')
        end
      end
    end
  end
end
