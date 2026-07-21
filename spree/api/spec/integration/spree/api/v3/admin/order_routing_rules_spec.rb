# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Routing Rules API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:channel) { store.default_channel }
  let(:channel_id) { channel.prefixed_id }

  path '/api/v3/admin/channels/{channel_id}/order_routing_rules' do
    parameter name: :channel_id, in: :path, type: :string, required: true

    get 'List order routing rules for a channel' do
      tags 'Channels'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the channel\'s routing rules in priority order. The rules engine walks them top-down; see the Order Routing guide.'
      admin_scope :read, :settings

      admin_sdk_example 'order-routing-rules/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'rules found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |r| r['type'] }).to eq(%w[preferred_location minimize_splits default_location])
        end
      end
    end

    post 'Create an order routing rule on a channel' do
      tags 'Channels'
      produces 'application/json'
      consumes 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Adds a rule to the channel\'s routing list. The `type` is the wire shorthand from `GET /order_routing_rules/types` (e.g. `preferred_location`). Omitting `position` appends the rule at the end of the list. Each rule kind can appear at most once per channel — a duplicate `type` is rejected with a validation error.'
      admin_scope :write, :settings

      admin_sdk_example 'order-routing-rules/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          type: { type: :string, example: 'preferred_location' },
          active: { type: :boolean },
          position: { type: :integer },
          preferences: { type: :object, additionalProperties: true }
        },
        required: ['type']
      }

      response '201', 'rule created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { type: 'default_location' } }

        before { channel.order_routing_rules.find_by(type: 'Spree::OrderRouting::Rules::DefaultLocation').destroy! }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['type']).to eq('default_location')
          expect(data['position']).to eq(3)
        end
      end

      response '422', 'unknown rule type' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { type: 'bogus_rule' } }

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['code']).to eq('unknown_order_routing_rule_type')
        end
      end
    end
  end

  path '/api/v3/admin/channels/{channel_id}/order_routing_rules/{id}' do
    parameter name: :channel_id, in: :path, type: :string, required: true
    parameter name: :id, in: :path, type: :string, required: true

    let(:rule) { channel.order_routing_rules.ordered.first }
    let(:id) { rule.prefixed_id }

    patch 'Update an order routing rule' do
      tags 'Channels'
      produces 'application/json'
      consumes 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a rule\'s `active` flag, `position` (the list reorders around it), or `preferences`. The rule kind cannot be changed — delete and re-create instead.'
      admin_scope :write, :settings

      admin_sdk_example 'order-routing-rules/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          active: { type: :boolean },
          position: { type: :integer },
          preferences: { type: :object, additionalProperties: true }
        }
      }

      response '200', 'rule updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { active: false, position: 2 } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['active']).to be(false)
          expect(data['position']).to eq(2)
        end
      end
    end

    delete 'Delete an order routing rule' do
      tags 'Channels'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :settings

      admin_sdk_example 'order-routing-rules/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'rule deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end

  path '/api/v3/admin/order_routing_rules/types' do
    get 'List available order routing rule types' do
      tags 'Channels'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Enumerates the registered rule kinds with their labels, descriptions and preference schemas — drives the "Add rule" picker in the admin dashboard. Plugins extend the list by registering `Spree::OrderRoutingRule` subclasses via `Spree.order_routing.rules`.'
      admin_scope :read, :settings

      admin_sdk_example 'order-routing-rules/types'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'types found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |t| t['type'] }).to contain_exactly('preferred_location', 'minimize_splits', 'default_location')
          expect(data.first).to include('label', 'description', 'preference_schema')
        end
      end
    end
  end
end
