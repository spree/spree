# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Checkout API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:user) { create(:user_with_addresses) }
  let!(:order) { create(:order_with_line_items, store: store, user: user) }

  path '/api/v3/store/checkout' do
    patch 'Update checkout' do
      tags 'Checkout'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates checkout info (email, addresses, special instructions). When addresses change, the order state is reverted to address to ensure shipments are recalculated.'

      sdk_example <<~JS
        const cart = await client.checkout.update({
          email: 'customer@example.com',
          ship_address: {
            firstname: 'John',
            lastname: 'Doe',
            address1: '123 Main St',
            city: 'New York',
            zipcode: '10001',
            country_iso: 'US',
            state_abbr: 'NY',
          },
        }, {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: 'x-spree-token', in: :header, type: :string, required: false
      parameter name: 'Idempotency-Key', in: :header, type: :string, required: false,
                description: 'Unique key for request idempotency.'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: 'email', example: 'customer@example.com' },
          special_instructions: { type: :string, example: 'Leave at door' },
          metadata: { type: :object, additionalProperties: true },
          bill_address: {
            type: :object,
            properties: {
              firstname: { type: :string }, lastname: { type: :string },
              address1: { type: :string }, address2: { type: :string },
              city: { type: :string }, zipcode: { type: :string },
              phone: { type: :string }, company: { type: :string },
              country_iso: { type: :string }, state_abbr: { type: :string }
            }
          },
          ship_address: {
            type: :object,
            properties: {
              firstname: { type: :string }, lastname: { type: :string },
              address1: { type: :string }, address2: { type: :string },
              city: { type: :string }, zipcode: { type: :string },
              phone: { type: :string }, company: { type: :string },
              country_iso: { type: :string }, state_abbr: { type: :string }
            }
          }
        }
      }

      response '200', 'checkout updated' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { special_instructions: 'Leave at door' } }

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('cart_')
          expect(data['special_instructions']).to eq('Leave at door')
        end
      end
    end
  end

  describe 'auto-advance behavior' do
    let(:country) { Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US') }
    let!(:us_state) { country.states.find_by(abbr: 'NY') || create(:state, country: country, abbr: 'NY', name: 'New York') }
    let!(:zone) { create(:zone, zone_members: [Spree::ZoneMember.new(zoneable: country)]) }
    let!(:shipping_method) { create(:shipping_method, zones: [zone]) }

    it 'auto-advances to payment after address submission' do
      # Put order in address state with email set
      order.update!(email: 'customer@example.com')
      order.next # cart -> address
      order.reload
      expect(order.state).to eq('address')

      patch '/api/v3/store/checkout',
            params: {
              ship_address: {
                firstname: 'John', lastname: 'Doe',
                address1: '123 Main St', city: 'New York',
                zipcode: '10001', country_iso: 'US', state_abbr: 'NY',
                phone: '555-1234'
              }
            }.to_json,
            headers: {
              'Content-Type' => 'application/json',
              'x-spree-api-key' => api_key.token,
              'Authorization' => "Bearer #{jwt_token}"
            }

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      # Advances through delivery (rates pre-selected) to payment
      expect(data['current_step']).to eq('payment')
    end

  end

  path '/api/v3/store/checkout/complete' do
    post 'Complete checkout' do
      tags 'Checkout'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Completes the checkout and finalizes the purchase. Returns an Order (not Cart).'

      sdk_example <<~JS
        const order = await client.checkout.complete({
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: 'x-spree-token', in: :header, type: :string, required: false
      parameter name: 'Idempotency-Key', in: :header, type: :string, required: false

      response '200', 'checkout completed' do
        let(:completable_order) do
          order = create(:order_with_line_items, store: store, user: user)
          Spree.checkout_advance_service.call(order: order)
          payment_method = create(:check_payment_method, stores: [store])
          create(:payment, order: order, amount: order.total, payment_method: payment_method, state: 'checkout')
          order.reload
        end
        let!(:_ensure_order) { completable_order }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema '$ref' => '#/components/schemas/Order'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('or_')
          expect(data['completed_at']).to be_present
        end
      end

      response '422', 'cannot complete' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

end
