# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Payments API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:order) { create(:order_ready_to_ship, store: store) }
  let!(:payment) { order.payments.first }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/orders/{order_id}/payments' do
    let(:order_id) { order.prefixed_id }

    get 'List payments' do
      tags 'Payments'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all payments for an order.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID'

      response '200', 'payments found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].length).to be >= 1
        end
      end
    end

    post 'Create a payment' do
      tags 'Payments'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a new payment for the order.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[payment_method_id],
        properties: {
          payment_method_id: { type: :string, description: 'Payment method ID or prefixed ID' },
          amount: { type: :number, example: 99.99 },
          source_id: { type: :string, description: 'Payment source prefixed ID' }
        }
      }

      response '201', 'payment created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:order_without_payment) { create(:completed_order_with_totals, store: store) }
        let(:order_id) { order_without_payment.prefixed_id }
        let(:payment_method) { create(:check_payment_method, stores: [store]) }
        let(:body) { { payment_method_id: payment_method.id, amount: order_without_payment.total } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['state']).to be_present
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/payments/{id}' do
    let(:order_id) { order.prefixed_id }
    let(:id) { payment.prefixed_id }

    get 'Show a payment' do
      tags 'Payments'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns details of a specific payment.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Payment prefixed ID'

      response '200', 'payment found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(payment.prefixed_id)
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/payments/{id}/capture' do
    patch 'Capture a payment' do
      tags 'Payments'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Captures a pending payment.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Payment prefixed ID'

      response '200', 'payment captured' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:order_id) { order.prefixed_id }
        let(:id) { payment.prefixed_id }

        before do
          payment.update_column(:state, 'pending') if payment.state != 'pending'
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(payment.prefixed_id)
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/payments/{id}/void' do
    patch 'Void a payment' do
      tags 'Payments'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Voids a payment.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Payment prefixed ID'

      response '200', 'payment voided' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:order_id) { order.prefixed_id }
        let(:id) { payment.prefixed_id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(payment.prefixed_id)
        end
      end
    end
  end
end
