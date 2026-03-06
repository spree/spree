# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Refunds API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:order) { create(:order_ready_to_ship, store: store) }
  let!(:payment) { order.payments.first }
  let!(:refund_reason) { create(:refund_reason) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/orders/{order_id}/refunds' do
    let(:order_id) { order.prefixed_id }

    get 'List refunds' do
      tags 'Refunds'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all refunds for an order.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID'

      response '200', 'refunds found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end

    post 'Create a refund' do
      tags 'Refunds'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a refund for a payment on the order. The refund is automatically processed via the payment gateway.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[payment_id amount],
        properties: {
          payment_id: { type: :string, description: 'Payment prefixed ID' },
          amount: { type: :number, example: 10.00 },
          refund_reason_id: { type: :string, description: 'Refund reason prefixed ID' }
        }
      }

      response '201', 'refund created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { payment_id: payment.prefixed_id, amount: 5.00, refund_reason_id: refund_reason.prefixed_id } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['amount']).to eq('5.0')
        end
      end
    end
  end
end
