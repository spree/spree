# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Promotion Rules API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:promotion) { create(:promotion) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:promotion_id) { promotion.prefixed_id }

  path '/api/v3/admin/promotions/{promotion_id}/promotion_rules' do
    parameter name: :promotion_id, in: :path, type: :string, required: true

    get 'List rules for a promotion' do
      tags 'Promotions'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :promotions

      admin_sdk_example 'promotion-rules/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'rules found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        before do
          Spree::Promotion::Rules::Currency.create!(promotion: promotion, preferred_currency: 'USD')
        end

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.size).to eq(1)
          expect(data.first['type']).to eq('currency')
          expect(data.first['preferences']).to include('currency' => 'USD')
        end
      end
    end

    post 'Create a rule on a promotion' do
      tags 'Promotions'
      produces 'application/json'
      consumes 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Adds a new rule to a promotion. The `type` is the wire shorthand from `GET /promotion_rules/types` (e.g. `currency`, `item_total`, `product`). Fully-qualified Ruby class names are also accepted for backward compatibility.'
      admin_scope :write, :promotions

      admin_sdk_example 'promotion-rules/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          type: { type: :string, example: 'currency' },
          preferences: { type: :object, additionalProperties: true }
        },
        required: ['type']
      }

      response '201', 'rule created with preferences' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { type: 'currency', preferences: { currency: 'EUR' } } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['type']).to eq('currency')
          expect(data['preferences']).to include('currency' => 'EUR')
        end
      end

      response '422', 'unknown rule type' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { type: 'bogus_rule' } }

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['code']).to eq('unknown_promotion_rule_type')
        end
      end
    end
  end

  path '/api/v3/admin/promotions/{promotion_id}/promotion_rules/{id}' do
    parameter name: :promotion_id, in: :path, type: :string, required: true
    parameter name: :id, in: :path, type: :string, required: true

    let(:rule) { Spree::Promotion::Rules::Currency.create!(promotion: promotion, preferred_currency: 'USD') }
    let(:id) { rule.prefixed_id }

    patch 'Update a rule\'s preferences' do
      tags 'Promotions'
      produces 'application/json'
      consumes 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :promotions

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { preferences: { type: :object, additionalProperties: true } }
      }

      response '200', 'rule updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { preferences: { currency: 'GBP' } } }

        run_test! do |response|
          expect(JSON.parse(response.body)['preferences']).to include('currency' => 'GBP')
        end
      end
    end

    delete 'Delete a rule from a promotion' do
      tags 'Promotions'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :promotions

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'rule deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end
end
