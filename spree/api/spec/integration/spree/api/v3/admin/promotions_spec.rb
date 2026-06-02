# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Promotions API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:promotion) { create(:promotion, name: 'Summer Sale', code: 'SUMMER') }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/promotions' do
    get 'List promotions' do
      tags 'Promotions'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the store\'s promotions, including manual coupon and automatic promotions.'
      admin_scope :read, :promotions

      admin_sdk_example 'promotions/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'promotions found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data).to be_an(Array)
          expect(data.first['name']).to eq('Summer Sale')
        end
      end
    end

    post 'Create a promotion' do
      tags 'Promotions'
      produces 'application/json'
      consumes 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Creates a new promotion. `code` is required for single-code coupon promotions;
        pass `multi_codes: true` with `number_of_codes` to auto-generate a batch.

        Rules and actions can be created in the same request by passing arrays of
        `{ type, preferences, ... }` rows. The server reconciles to the desired set:
        new rows are built, existing rows (by `id`) are updated, omitted rows are removed.
      DESC
      admin_scope :write, :promotions

      admin_sdk_example 'promotions/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          code: { type: :string, nullable: true },
          description: { type: :string, nullable: true },
          starts_at: { type: :string, format: 'date-time', nullable: true },
          expires_at: { type: :string, format: 'date-time', nullable: true },
          usage_limit: { type: :integer, nullable: true },
          match_policy: { type: :string, enum: %w[all any] },
          kind: { type: :string, enum: %w[coupon_code automatic] },
          multi_codes: { type: :boolean },
          number_of_codes: { type: :integer, nullable: true },
          code_prefix: { type: :string, nullable: true },
          promotion_category_id: { type: :string, nullable: true },
          rules: {
            type: :array,
            items: {
              type: :object,
              properties: {
                type: { type: :string, example: 'currency' },
                preferences: { type: :object, additionalProperties: true },
                product_ids: { type: :array, items: { type: :string } },
                category_ids: { type: :array, items: { type: :string } },
                customer_ids: { type: :array, items: { type: :string } }
              },
              required: ['type']
            }
          },
          actions: {
            type: :array,
            items: {
              type: :object,
              properties: {
                type: { type: :string, example: 'free_shipping' },
                preferences: { type: :object, additionalProperties: true },
                calculator: {
                  type: :object,
                  properties: {
                    type: { type: :string, example: 'flat_percent_item_total' },
                    preferences: { type: :object, additionalProperties: true }
                  }
                }
              },
              required: ['type']
            }
          }
        },
        required: ['name']
      }

      response '201', 'promotion created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'Black Friday', code: 'BLACKFRIDAY' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Black Friday')
          expect(data['code']).to eq('blackfriday')
        end
      end

      response '201', 'promotion created with rules and actions' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_a) { create(:product) }
        let(:product_b) { create(:product) }
        let(:body) do
          {
            name: 'Black Friday',
            code: 'BLACKFRIDAY-OS',
            kind: 'coupon_code',
            match_policy: 'all',
            rules: [
              { type: 'currency', preferences: { currency: 'USD' } },
              {
                type: 'item_total',
                preferences: { amount_min: 100, operator_min: 'gte' }
              },
              {
                type: 'product',
                preferences: { match_policy: 'any' },
                product_ids: [product_a.prefixed_id, product_b.prefixed_id]
              }
            ],
            actions: [
              {
                type: 'create_item_adjustments',
                calculator: {
                  type: 'percent_on_line_item',
                  preferences: { percent: 25 }
                }
              },
              { type: 'free_shipping' }
            ]
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          promotion = Spree::Promotion.find_by_prefix_id(data['id'])

          expect(promotion.rules.map(&:class)).to contain_exactly(
            Spree::Promotion::Rules::Currency,
            Spree::Promotion::Rules::ItemTotal,
            Spree::Promotion::Rules::Product
          )
          expect(promotion.actions.map(&:class)).to contain_exactly(
            Spree::Promotion::Actions::CreateItemAdjustments,
            Spree::Promotion::Actions::FreeShipping
          )

          product_rule = promotion.rules.find { |r| r.is_a?(Spree::Promotion::Rules::Product) }
          expect(product_rule.product_ids).to contain_exactly(product_a.id, product_b.id)

          adjustment_action = promotion.actions.find { |a| a.is_a?(Spree::Promotion::Actions::CreateItemAdjustments) }
          expect(adjustment_action.calculator).to be_a(Spree::Calculator::PercentOnLineItem)
          expect(adjustment_action.calculator.preferred_percent).to eq(25)
        end
      end

      response '422', 'invalid params' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: '' } }

        run_test!
      end
    end
  end

  path '/api/v3/admin/promotions/{id}' do
    let(:id) { promotion.prefixed_id }

    get 'Show a promotion' do
      tags 'Promotions'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :promotions

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'promotion found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(promotion.prefixed_id)
        end
      end
    end

    patch 'Update a promotion' do
      tags 'Promotions'
      produces 'application/json'
      consumes 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Updates a promotion. The `rules` and `actions` arrays are treated as
        a *desired set* — rows with `id` update in place, rows without `id` are
        built fresh, and any existing row not present in the array is destroyed.
        Pass `rules: []` or `actions: []` to clear them.
      DESC
      admin_scope :write, :promotions

      admin_sdk_example 'promotions/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string, nullable: true },
          code: { type: :string, nullable: true },
          starts_at: { type: :string, format: 'date-time', nullable: true },
          expires_at: { type: :string, format: 'date-time', nullable: true },
          usage_limit: { type: :integer, nullable: true },
          match_policy: { type: :string, enum: %w[all any] },
          kind: { type: :string, enum: %w[coupon_code automatic] },
          promotion_category_id: { type: :string, nullable: true },
          rules: {
            type: :array,
            items: {
              type: :object,
              properties: {
                id: { type: :string, nullable: true, description: 'Pass to update an existing rule; omit to build a new one' },
                type: { type: :string, example: 'currency' },
                preferences: { type: :object, additionalProperties: true },
                product_ids: { type: :array, items: { type: :string } },
                category_ids: { type: :array, items: { type: :string } },
                customer_ids: { type: :array, items: { type: :string } }
              },
              required: ['type']
            }
          },
          actions: {
            type: :array,
            items: {
              type: :object,
              properties: {
                id: { type: :string, nullable: true },
                type: { type: :string, example: 'free_shipping' },
                preferences: { type: :object, additionalProperties: true },
                calculator: {
                  type: :object,
                  properties: {
                    type: { type: :string, example: 'flat_percent_item_total' },
                    preferences: { type: :object, additionalProperties: true }
                  }
                }
              },
              required: ['type']
            }
          }
        }
      }

      response '200', 'promotion updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { description: 'Updated description' } }

        run_test! do |response|
          expect(JSON.parse(response.body)['description']).to eq('Updated description')
        end
      end

      response '200', 'rules and actions reconciled to desired set' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let!(:existing_rule) do
          Spree::Promotion::Rules::Currency.create!(promotion: promotion, preferred_currency: 'USD')
        end
        let!(:existing_action) do
          calc = Spree::Calculator::FlatRate.new(preferred_amount: 10)
          Spree::Promotion::Actions::CreateItemAdjustments.create!(promotion: promotion, calculator: calc)
        end
        let!(:dropped_rule) { Spree::Promotion::Rules::FirstOrder.create!(promotion: promotion) }

        let(:body) do
          {
            name: 'Holiday Sale',
            rules: [
              # Update existing currency rule
              {
                id: existing_rule.prefixed_id,
                type: 'currency',
                preferences: { currency: 'EUR' }
              },
              # Add a new rule
              {
                type: 'item_total',
                preferences: { amount_min: 50, operator_min: 'gte' }
              }
              # `dropped_rule` (FirstOrder) omitted — should be destroyed
            ],
            actions: [
              # Swap calculator type on existing action
              {
                id: existing_action.prefixed_id,
                type: 'create_item_adjustments',
                calculator: {
                  type: 'percent_on_line_item',
                  preferences: { percent: 15 }
                }
              }
            ]
          }
        end

        run_test! do |_response|
          promotion.reload
          expect(promotion.name).to eq('Holiday Sale')

          # Existing currency rule was updated, FirstOrder dropped, ItemTotal added
          expect(promotion.rules.map(&:class)).to contain_exactly(
            Spree::Promotion::Rules::Currency,
            Spree::Promotion::Rules::ItemTotal
          )
          expect(existing_rule.reload.preferred_currency).to eq('EUR')
          expect(Spree::PromotionRule.where(id: dropped_rule.id)).to be_empty

          # Action calculator was swapped in place
          existing_action.reload
          expect(existing_action.calculator).to be_a(Spree::Calculator::PercentOnLineItem)
          expect(existing_action.calculator.preferred_percent).to eq(15)
        end
      end

      response '200', 'rules and actions cleared with empty arrays' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let!(:rule_to_drop) do
          Spree::Promotion::Rules::Currency.create!(promotion: promotion, preferred_currency: 'USD')
        end
        let(:body) { { rules: [], actions: [] } }

        run_test! do |_response|
          promotion.reload
          expect(promotion.rules).to be_empty
          expect(Spree::PromotionRule.where(id: rule_to_drop.id)).to be_empty
        end
      end
    end

    delete 'Delete a promotion' do
      tags 'Promotions'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :promotions

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '204', 'promotion deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end

  path '/api/v3/admin/promotion_actions/types' do
    get 'List available promotion action types' do
      tags 'Promotions'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the registered Spree::PromotionAction subclasses with their preference schemas. Used by admin UIs to populate the "Add action" picker and render generic preference forms.'
      admin_scope :read, :promotions

      admin_sdk_example 'promotions/action-types'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'action types found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data).to be_an(Array)
          expect(data).to all(include('type', 'label', 'preference_schema'))
        end
      end
    end
  end

  path '/api/v3/admin/promotion_rules/types' do
    get 'List available promotion rule types' do
      tags 'Promotions'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the registered Spree::PromotionRule subclasses with their preference schemas.'
      admin_scope :read, :promotions

      admin_sdk_example 'promotions/rule-types'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'rule types found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data).to be_an(Array)
          expect(data).to all(include('type', 'label', 'preference_schema'))
        end
      end
    end
  end
end
