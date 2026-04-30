# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Orders API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:order) { create(:order, store: store, state: 'cart', email: 'test@example.com') }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/orders' do
    get 'List orders' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a paginated list of orders for the current store.'
      admin_scope :read, :orders

      admin_sdk_example <<~JS
        const { data: orders, meta } = await client.orders.list({
          status_eq: 'complete',
          completed_at_gt: '2026-01-01',
          sort: '-completed_at',
          limit: 25,
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort field (e.g., created_at, -created_at, completed_at)'
      parameter name: :'q[state_eq]', in: :query, type: :string, required: false,
                description: 'Filter by state (cart, address, delivery, payment, confirm, complete, canceled)'
      parameter name: :'q[email_cont]', in: :query, type: :string, required: false,
                description: 'Filter by email (contains)'
      parameter name: :'q[number_eq]', in: :query, type: :string, required: false,
                description: 'Filter by order number'
      parameter name: :'q[completed_at_gt]', in: :query, type: :string, required: false,
                description: 'Filter by completed after date'

      response '200', 'orders found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['meta']).to include('page', 'limit', 'count', 'pages')
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a draft order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]

      admin_sdk_example <<~JS
        // One-shot order create: customer, items, addresses, market, notes,
        // metadata, and a coupon code in a single call. Everything except
        // `email` is optional.
        const order = await client.orders.create({
          email: 'jane@example.com',
          customer_id: 'cus_UkLWZg9DAJ',           // Existing customer; omit for guest orders
          use_customer_default_address: false,     // true to copy the customer's saved addresses

          currency: 'USD',
          market_id: 'mkt_UkLWZg9DAJ',
          locale: 'en-US',

          customer_note: 'Please leave at the front desk.',
          internal_note: 'VIP customer — handle with care.',
          metadata: {
            external_reference: 'subscription_invoice_2026_04',
            source: 'recurring-engine',
          },

          // Items: each variant_id + quantity. Optional metadata per line.
          items: [
            { variant_id: 'variant_k5nR8xLq', quantity: 2 },
            { variant_id: 'variant_QXyZ12abCD', quantity: 1, metadata: { gift: true } },
          ],

          // Provide addresses inline OR by ID (existing customer addresses).
          shipping_address: {
            first_name: 'Jane',
            last_name: 'Doe',
            address1: '350 Fifth Avenue',
            address2: 'Floor 42',
            city: 'New York',
            postal_code: '10118',
            country_iso: 'US',
            state_abbr: 'NY',
            phone: '+1 212 555 1234',
            company: 'Acme Inc.',
          },
          // shipping_address_id: 'addr_UkLWZg9DAJ',  // alternative to inline

          billing_address: {
            first_name: 'Jane',
            last_name: 'Doe',
            address1: '350 Fifth Avenue',
            city: 'New York',
            postal_code: '10118',
            country_iso: 'US',
            state_abbr: 'NY',
            phone: '+1 212 555 1234',
          },
          // billing_address_id: 'addr_UkLWZg9DAJ',

          // Optional. Invalid codes are non-fatal — the order is created either way.
          coupon_code: 'WELCOME10',
        })
      JS

      description <<~DESC
        Creates a new draft order in one shot. Customer, items, addresses, currency,
        market, locale, notes, metadata, and a coupon code can all be provided inline.

        Invalid coupon codes are non-fatal — the order is created and the failure
        is reported on the service result (not in the API response body for now).
      DESC
      admin_scope :write, :orders

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, example: 'customer@example.com' },
          customer_id: { type: :string, description: 'Customer ID. Alias: user_id (legacy).' },
          use_customer_default_address: { type: :boolean, description: "When true with customer_id, copies the customer's saved billing/shipping addresses onto the order." },
          currency: { type: :string, example: 'USD' },
          market_id: { type: :string, description: 'Market ID' },
          locale: { type: :string, example: 'en-US' },
          customer_note: { type: :string, description: 'Public, customer-visible note' },
          internal_note: { type: :string, description: 'Staff-only note' },
          metadata: { type: :object, description: 'Arbitrary key/value metadata' },
          shipping_address: {
            type: :object,
            properties: {
              first_name: { type: :string }, last_name: { type: :string },
              address1: { type: :string }, city: { type: :string },
              postal_code: { type: :string }, country_iso: { type: :string },
              state_abbr: { type: :string }, phone: { type: :string }
            }
          },
          shipping_address_id: { type: :string, description: 'Existing customer address ID' },
          billing_address: {
            type: :object,
            properties: {
              first_name: { type: :string }, last_name: { type: :string },
              address1: { type: :string }, city: { type: :string },
              postal_code: { type: :string }, country_iso: { type: :string },
              state_abbr: { type: :string }, phone: { type: :string }
            }
          },
          billing_address_id: { type: :string, description: 'Existing customer address ID' },
          items: {
            type: :array,
            items: {
              type: :object,
              required: %w[variant_id quantity],
              properties: {
                variant_id: { type: :string, description: 'Variant ID' },
                quantity: { type: :integer, example: 1 },
                metadata: { type: :object }
              }
            }
          },
          coupon_code: { type: :string, description: 'Optional. Applied non-fatally; invalid codes do not block creation.' }
        }
      }

      response '201', 'order created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { email: 'new-order@example.com' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['email']).to eq('new-order@example.com')
        end
      end
    end
  end

  path '/api/v3/admin/orders/{id}' do
    let(:id) { order.prefixed_id }

    get 'Show an order' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns full order details including admin-only fields.'
      admin_scope :read, :orders

      admin_sdk_example <<~JS
        const order = await client.orders.get('or_UkLWZg9DAJ', {
          expand: ['items', 'fulfillments', 'payments', 'customer'],
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order ID (e.g., or_xxx)'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., user)'

      response '200', 'order found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(order.prefixed_id)
        end
      end

      response '404', 'order not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'or_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update an order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates an order. Supports updating email, addresses, special instructions, and line items.'
      admin_scope :write, :orders

      admin_sdk_example <<~JS
        const order = await client.orders.update('or_UkLWZg9DAJ', {
          email: 'updated@example.com',
          internal_note: 'VIP — gift wrap on next order',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string },
          special_instructions: { type: :string },
          internal_note: { type: :string },
          ship_address: {
            type: :object,
            properties: {
              firstname: { type: :string },
              lastname: { type: :string },
              address1: { type: :string },
              city: { type: :string },
              zipcode: { type: :string },
              country_iso: { type: :string },
              state_abbr: { type: :string },
              phone: { type: :string }
            }
          },
          bill_address: {
            type: :object,
            properties: {
              firstname: { type: :string },
              lastname: { type: :string },
              address1: { type: :string },
              city: { type: :string },
              zipcode: { type: :string },
              country_iso: { type: :string },
              state_abbr: { type: :string },
              phone: { type: :string }
            }
          },
          items: {
            type: :array,
            items: {
              type: :object,
              required: %w[variant_id],
              properties: {
                variant_id: { type: :string, description: 'Variant ID' },
                quantity: { type: :integer, example: 1 },
                metadata: { type: :object }
              }
            }
          }
        }
      }

      response '200', 'order updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { email: 'updated@example.com' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['email']).to eq('updated@example.com')
        end
      end
    end

    delete 'Delete a draft order' do
      tags 'Orders'
      security [api_key: [], bearer_auth: []]
      description 'Deletes a draft order. Completed orders cannot be deleted.'
      admin_scope :write, :orders

      admin_sdk_example <<~JS
        await client.orders.delete('or_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order ID'

      response '204', 'order deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end

  path '/api/v3/admin/orders/{id}/complete' do
    patch 'Complete an order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Completes an order in the `confirm` state, marking it as placed.

        Set `notify_customer: true` to send the order confirmation email.
      DESC
      admin_scope :write, :orders

      admin_sdk_example <<~JS
        const order = await client.orders.complete('or_UkLWZg9DAJ', {
          notify_customer: true,
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          notify_customer: { type: :boolean, description: 'Send the order confirmation email after completion.' }
        }
      }

      response '200', 'order completed' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let!(:order) { create(:order_ready_to_ship, store: store) }
        let(:id) { order.prefixed_id }
        let(:body) { { notify_customer: false } }

        run_test!
      end

      response '422', 'order cannot be completed' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let!(:order) { create(:order_with_line_items, store: store) }
        let(:id) { order.prefixed_id }
        let(:body) { {} }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/orders/{id}/cancel' do
    patch 'Cancel an order' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Cancels a completed order.'
      admin_scope :write, :orders

      admin_sdk_example <<~JS
        const order = await client.orders.cancel('or_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order ID'

      response '200', 'order canceled' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let!(:order) { create(:completed_order_with_totals, store: store) }
        let(:id) { order.prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/admin/orders/{id}/approve' do
    patch 'Approve an order' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Approves an order (e.g., for fraud review).'
      admin_scope :write, :orders

      admin_sdk_example <<~JS
        const order = await client.orders.approve('or_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order ID'

      response '200', 'order approved' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let!(:order) { create(:completed_order_with_totals, store: store) }
        let(:id) { order.prefixed_id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['approved_at']).to be_present
        end
      end
    end
  end

  path '/api/v3/admin/orders/{id}/resume' do
    patch 'Resume a canceled order' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Resumes a previously canceled order.'
      admin_scope :write, :orders

      admin_sdk_example <<~JS
        const order = await client.orders.resume('or_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order ID'

      response '200', 'order resumed' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let!(:order) { create(:completed_order_with_totals, store: store) }
        let(:id) { order.prefixed_id }

        before do
          order.canceled_by(admin_user)
        end

        run_test!
      end
    end
  end

  path '/api/v3/admin/orders/{id}/resend_confirmation' do
    post 'Resend confirmation email' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Publishes the order.completed event to trigger confirmation email delivery.'
      admin_scope :write, :orders

      admin_sdk_example <<~JS
        await client.orders.resendConfirmation('or_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order ID'

      response '200', 'confirmation resent' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let!(:order) { create(:completed_order_with_totals, store: store) }
        let(:id) { order.prefixed_id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(order.prefixed_id)
        end
      end
    end
  end
end
