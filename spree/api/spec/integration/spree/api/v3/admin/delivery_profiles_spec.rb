# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Delivery Profiles API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }
  let(:store) { @default_store }

  path '/api/v3/admin/delivery_profiles' do
    get 'List delivery profiles' do
      tags 'Delivery'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Fulfillment profiles group products with the stock locations, delivery zones and delivery methods that fulfill them. Every store has exactly one default profile.'
      admin_scope :read, :settings

      admin_sdk_example 'delivery-profiles/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'delivery profiles found' do

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |row| row['default'] }).to include(true)
        end
      end
    end

    post 'Create a delivery profile' do
      tags 'Delivery'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a delivery profile. `kind` selects the registered profile kind (shipping, digital, extension kinds); `stock_location_ids` limits fulfillment to those locations — empty means every store location.'
      admin_scope :write, :settings

      admin_sdk_example 'delivery-profiles/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Oversized' },
          kind: { type: :string, example: 'shipping', description: 'Registered profile kind; defaults to shipping.' },
          default: { type: :boolean },
          stock_location_ids: { type: :array, items: { type: :string }, description: 'Empty means every store location.' }
        },
        required: %w[name]
      }

      response '201', 'delivery profile created' do
        let(:body) { { name: "Oversized #{Time.current.to_f}" } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['kind']).to eq('shipping')
          expect(data['default']).to be(false)
        end
      end

      response '422', 'validation error' do
        let(:body) { { name: '' } }

        run_test!
      end
    end
  end

  path '/api/v3/admin/delivery_profiles/{delivery_profile_id}/origin_groups' do
    parameter name: :delivery_profile_id, in: :path, type: :string

    post 'Create an origin group' do
      tags 'Delivery'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Origin groups partition a profile\'s fulfillment origins: zones and methods belong to a group, so the same products can quote different rate tables per warehouse. `stock_location_ids` replaces the full membership; empty means every store location.'
      admin_scope :write, :settings

      admin_sdk_example 'delivery-profiles/origin-groups-create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, nullable: true, example: 'EU warehouse' },
          position: { type: :integer, nullable: true },
          stock_location_ids: { type: :array, items: { type: :string }, description: 'Empty means every store location.' }
        }
      }

      response '201', 'origin group created' do
        let(:delivery_profile_id) { create(:delivery_profile, store: store, name: "Grouped #{Time.current.to_f}").prefixed_id }
        let(:body) { { name: 'EU warehouse', stock_location_ids: [create(:stock_location, store: store).prefixed_id] } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('EU warehouse')
          expect(data['stock_location_ids'].size).to eq(1)
        end
      end
    end
  end

  path '/api/v3/admin/delivery_profiles/{id}' do
    parameter name: :id, in: :path, type: :string

    patch 'Update a delivery profile' do
      tags 'Delivery'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :settings

      admin_sdk_example 'delivery-profiles/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          default: { type: :boolean },
          stock_location_ids: { type: :array, items: { type: :string } }
        }
      }

      response '200', 'delivery profile updated' do
        let(:profile) { create(:delivery_profile, store: store, name: "Bulky #{Time.current.to_f}") }
        let(:id) { profile.prefixed_id }
        let(:body) { { stock_location_ids: [create(:stock_location, store: store).prefixed_id] } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['stock_location_ids'].size).to eq(1)
        end
      end
    end

    delete 'Delete a delivery profile' do
      tags 'Delivery'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'The default profile and profiles still referenced by products cannot be deleted.'
      admin_scope :write, :settings

      admin_sdk_example 'delivery-profiles/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'delivery profile deleted' do
        let(:id) { create(:delivery_profile, store: store, name: "Doomed #{Time.current.to_f}").prefixed_id }

        run_test!
      end
    end
  end
end
