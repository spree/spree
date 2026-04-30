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
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all payments for an order.'
      admin_scope :read, :payments

      admin_sdk_example <<~JS
        const { data: payments } = await client.orders.payments.list('or_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'

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
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a new payment for the order.'
      admin_scope :write, :payments

      admin_sdk_example <<~JS
        const payment = await client.orders.payments.create('or_UkLWZg9DAJ', {
          payment_method_id: 'pm_UkLWZg9DAJ',
          amount: 99.99,
          source_id: 'cc_UkLWZg9DAJ',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[payment_method_id],
        properties: {
          payment_method_id: { type: :string, description: 'Payment method ID' },
          amount: { type: :number, example: 99.99 },
          source_id: { type: :string, description: 'Payment source ID' }
        }
      }

      response '201', 'payment created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:order_without_payment) { create(:completed_order_with_totals, store: store) }
        let(:order_id) { order_without_payment.prefixed_id }
        let(:payment_method) { create(:check_payment_method, stores: [store]) }
        let(:body) { { payment_method_id: payment_method.prefixed_id, amount: order_without_payment.total } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to be_present
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/payments/{id}' do
    let(:order_id) { order.prefixed_id }
    let(:id) { payment.prefixed_id }

    get 'Show a payment' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns details of a specific payment.'
      admin_scope :read, :payments

      admin_sdk_example <<~JS
        const payment = await client.orders.payments.get('or_UkLWZg9DAJ', 'pay_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Payment ID'

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
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Captures a pending payment.'
      admin_scope :write, :payments

      admin_sdk_example <<~JS
        const payment = await client.orders.payments.capture('or_UkLWZg9DAJ', 'pay_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Payment ID'

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
          expect(data['status']).to eq('completed')
          expect(payment.reload.state).to eq('completed')
        end
      end

      response '422', 'capture failed' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:order_id) { order.prefixed_id }
        let(:id) { payment.prefixed_id }

        before do
          # Bogus gateway forces a failure when the authorization doesn't start with `BGS-`.
          payment.update_columns(state: 'pending', response_code: 'INVALID-AUTH')
        end

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['message']).to eq('Bogus Gateway: Forced failure')
          expect(payment.reload.state).to eq('failed')
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/payments/{id}/void' do
    patch 'Void a payment' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Voids a payment.'
      admin_scope :write, :payments

      admin_sdk_example <<~JS
        const payment = await client.orders.payments.void('or_UkLWZg9DAJ', 'pay_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Payment ID'

      response '200', 'payment voided' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:order_id) { order.prefixed_id }
        let(:id) { payment.prefixed_id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(payment.prefixed_id)
          expect(data['status']).to eq('void')
          expect(payment.reload.state).to eq('void')
        end
      end
    end
  end
end
