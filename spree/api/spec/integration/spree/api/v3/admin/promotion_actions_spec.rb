# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Promotion Actions API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:promotion) { create(:promotion) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:promotion_id) { promotion.prefixed_id }

  path '/api/v3/admin/promotions/{promotion_id}/promotion_actions' do
    parameter name: :promotion_id, in: :path, type: :string, required: true

    get 'List actions for a promotion' do
      tags 'Promotions'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :promotions

      admin_sdk_example 'promotion-actions/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      filter_parameters_for

      response '200', 'actions found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        before do
          Spree::Promotion::Actions::FreeShipping.create!(promotion: promotion)
        end

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.size).to eq(1)
          expect(data.first['type']).to eq('free_shipping')
          expect(data.first).not_to have_key('preference_schema')
        end
      end
    end

    post 'Create an action on a promotion' do
      tags 'Promotions'
      produces 'application/json'
      consumes 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Adds a new action to a promotion. The `type` is the wire shorthand from `GET /promotion_actions/types` (e.g. `free_shipping`, `create_item_adjustments`).'
      admin_scope :write, :promotions

      admin_sdk_example 'promotion-actions/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      request_body_for

      response '201', 'action created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { type: 'free_shipping' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['type']).to eq('free_shipping')
          expect(data['promotion_id']).to eq(promotion.prefixed_id)
        end
      end

      response '422', 'unknown action type' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { type: 'bogus_action' } }

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['code']).to eq('unknown_promotion_action_type')
        end
      end
    end
  end

  path '/api/v3/admin/promotions/{promotion_id}/promotion_actions/{id}' do
    parameter name: :promotion_id, in: :path, type: :string, required: true
    parameter name: :id, in: :path, type: :string, required: true

    let(:action) { Spree::Promotion::Actions::FreeShipping.create!(promotion: promotion) }
    let(:id) { action.prefixed_id }

    patch 'Update an action on a promotion' do
      tags 'Promotions'
      produces 'application/json'
      consumes 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Changes an action's settings. For adjustment actions, `calculator`
        sets the calculator and its preferences; sending a different
        calculator `type` swaps it. The action's own `type` is fixed once
        created.
      DESC
      admin_scope :write, :promotions

      admin_sdk_example 'promotion-actions/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      request_body_for

      response '200', 'action updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:action) do
          Spree::Promotion::Actions::CreateItemAdjustments.create!(
            promotion: promotion, calculator: Spree::Calculator::FlatRate.new(preferred_amount: 10)
          )
        end
        let(:body) { { calculator: { type: 'percent_on_line_item', preferences: { percent: '15' } } } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['type']).to eq('create_item_adjustments')
          expect(action.reload.calculator).to be_a(Spree::Calculator::PercentOnLineItem)
        end
      end
    end

    delete 'Delete an action from a promotion' do
      tags 'Promotions'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :promotions

      admin_sdk_example 'promotion-actions/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'action deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end
end
