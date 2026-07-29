# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Adjustment Lines API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:order) { create(:completed_order_with_totals, store: store) }
  let(:line_item) { order.line_items.first }
  let(:order_id) { order.prefixed_id }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }

  path '/api/v3/admin/orders/{order_id}/tax_lines' do
    get 'List tax lines' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Typed tax rows on the order. Read-only — written exclusively by the tax provider.'
      admin_scope :read, :orders

      admin_sdk_example 'orders/tax-lines-list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'

      response '200', 'tax lines found' do
        before { create(:tax_line, order: order, line_item: line_item, amount: 1.5, rate: 0.15, label: 'VAT 15%') }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].first['label']).to eq('VAT 15%')
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/discounts' do
    get 'List discounts' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Typed discount rows (promotion-sourced and manual) on the order.'
      admin_scope :read, :orders

      admin_sdk_example 'orders/discounts-list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'

      response '200', 'discounts found' do
        before { create(:discount, order: order, line_item: line_item, amount: -2, label: 'Loyalty', kind: 'manual') }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].first['kind']).to eq('manual')
        end
      end
    end

    post 'Create manual discount' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a manual discount. With line_item_id a single row is created; without it the amount is distributed across line items (largest remainder). This is the sanctioned post-placement discount path and works on completed orders.'
      admin_scope :write, :orders

      admin_sdk_example 'orders/discounts-create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          label: { type: :string, example: 'Customer appeasement' },
          value: { type: :number, example: 10 },
          value_type: { type: :string, enum: %w[flat percent], example: 'flat' },
          line_item_id: { type: :string, nullable: true, example: 'item_abc123', description: 'Target line item; omit to distribute order-level' }
        },
        required: %w[label value]
      }

      response '201', 'discount created' do
        let(:body) { { label: 'Appeasement', value: 3, value_type: 'flat', line_item_id: line_item.prefixed_id } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].first['amount']).to eq('-3.0')
        end
      end

      response '422', 'invalid discount' do
        let(:body) { { label: 'Bad', value: -1 } }

        run_test!
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/fees' do
    post 'Create fee' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a fee (surcharge, handling, gift wrap, COD). Order-level when no target is given. Works on completed orders.'
      admin_scope :write, :orders

      admin_sdk_example 'orders/fees-create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          label: { type: :string, example: 'Gift wrap' },
          amount: { type: :number, example: 4 },
          kind: { type: :string, example: 'gift_wrap', description: "Defaults to 'surcharge'" },
          line_item_id: { type: :string, nullable: true },
          fulfillment_id: { type: :string, nullable: true }
        },
        required: %w[label amount]
      }

      response '201', 'fee created' do
        let(:body) { { label: 'Gift wrap', amount: 4, kind: 'gift_wrap' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['label']).to eq('Gift wrap')
          expect(data['amount']).to eq('4.0')
        end
      end
    end
  end
end
