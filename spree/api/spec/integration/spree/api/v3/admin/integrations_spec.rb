# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Integrations API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }

  # OpenAPI examples are generated with a representative demo integration —
  # real types ship with provider gems (e.g. spree_easypost).
  let(:demo_integration_class) do
    Class.new(Spree::Integration) do
      preference :api_key, :password
      preference :account_number, :string

      def self.name = 'SpreeCarrier::Integration'
      def self.integration_name = 'Carrier'
      def self.integration_group = 'shipping'
    end
  end

  before do
    stub_const('SpreeCarrier::Integration', demo_integration_class)
    Spree.integrations << 'SpreeCarrier::Integration'
  end

  after { Spree.integrations.delete('SpreeCarrier::Integration') }

  path '/api/v3/admin/integrations' do
    get 'List integrations' do
      tags 'Integrations'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the integrations connected to the current store. Secret preference values are masked.'
      admin_scope :read, :integrations

      admin_sdk_example 'integrations/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'integrations found' do
        before { SpreeCarrier::Integration.create!(store: store, preferences: { api_key: 'sk-secret', account_number: '42' }) }

        run_test! do |response|
          data = JSON.parse(response.body)
          entry = data['data'].first
          expect(entry['type']).to eq('carrier')
          expect(entry['preferences']['api_key']).to start_with('••••')
        end
      end
    end

    post 'Connect integration' do
      tags 'Integrations'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Connects an integration type to the current store. Setting active: true verifies the connection and fails with 422 when it cannot connect. Submitting a masked secret value back keeps the stored secret.'
      admin_scope :write, :integrations

      admin_sdk_example 'integrations/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          type: { type: :string, example: 'carrier', description: 'Wire shorthand from GET /integrations/types' },
          active: { type: :boolean, example: false },
          preferences: { type: :object, example: { api_key: 'sk-secret', account_number: '42' } }
        },
        required: %w[type]
      }

      response '201', 'integration connected' do
        let(:body) { { type: 'carrier', preferences: { api_key: 'sk-secret' } } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['type']).to eq('carrier')
          expect(data['active']).to be false
        end
      end
    end
  end

  path '/api/v3/admin/integrations/types' do
    get 'List integration types' do
      tags 'Integrations'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Every registered integration type with its gallery metadata and configuration schema. Pure registry discovery — read live connection state from GET /integrations.'
      admin_scope :read, :integrations

      admin_sdk_example 'integrations/types'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'integration types found' do
        run_test! do |response|
          data = JSON.parse(response.body)
          entry = data['data'].find { |row| row['type'] == 'carrier' }
          expect(entry['preference_schema']).to be_an(Array)
        end
      end
    end
  end

  path '/api/v3/admin/integrations/{id}/test' do
    post 'Test integration connection' do
      tags 'Integrations'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Runs a live connection check against the provider. Nothing is persisted; a failed check reports the seller error message.'
      admin_scope :write, :integrations

      admin_sdk_example 'integrations/test'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string

      response '200', 'connection checked' do
        let(:id) do
          SpreeCarrier::Integration.create!(store: store, preferences: { api_key: 'sk-secret' }).prefixed_id
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['connected']).to be true
        end
      end
    end
  end
end
