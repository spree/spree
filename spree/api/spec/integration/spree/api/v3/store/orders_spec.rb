# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Orders API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:user) { create(:user_with_addresses) }

  path '/api/v3/store/orders/{id}' do
    get 'Get an order' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESCRIPTION
        Returns a completed purchase. Accessible via JWT (authenticated users) or order token header (guests).

        Resolves three kinds of id: the order's own (`or_…`), the id of the cart it was placed from, and the
        id of an order group (`ogrp_…`). The cart's id is the handle a storefront keeps through checkout, so
        a confirmation page can ask what its cart became without having learned a new one.

        A checkout that reached several sellers divided into one order per seller, and the cart moved up to
        the group holding them — so that handle, and the group's own id, answer with the **order group**,
        with the per-seller orders nested inside it. Every other lookup answers with an **order**. The two
        are told apart by the id prefix (`ogrp_` vs `or_`), or by the presence of `orders`.
      DESCRIPTION

      sdk_example 'orders/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Prefixed ID of the order, of the cart it was placed from, or of its order group'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Order token for guest access'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (items, fulfillments, payments, discounts, billing_address, shipping_address, gift_card). Use "none" to skip associations.'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., total,amount_due,item_count). id is always included.'

      response '200', 'order found (authenticated)' do
        let(:completed_order) { create(:completed_order_with_totals, store: store, customer: user) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { completed_order.to_param }

        before do
          create(:fee, order: completed_order, amount: 12, label: 'Import duty', kind: 'duty')
          completed_order.reload.recalculate_totals!
        end

        schema '$ref' => '#/components/schemas/Order'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('or_')
          expect(data['number']).to eq(completed_order.number)
          expect(data['fees'].map { |fee| fee['kind'] }).to eq(['duty'])
          expect(data['fee_total']).to eq('12.00')
          expect(data['completed_at']).to be_present
          expect(data).not_to have_key('token')
          expect(data).not_to have_key('checkout_steps')
          expect(data).not_to have_key('state_lock_version')
        end
      end

      response '200', 'order found (guest via order token)' do
        let(:guest_order) { create(:completed_order_with_totals, store: store, customer: nil, email: 'guest@example.com') }
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { guest_order.to_param }
        let(:'x-spree-token') { guest_order.token }

        before do
          create(:fee, order: guest_order, amount: 12, label: 'Import duty', kind: 'duty')
          guest_order.reload.recalculate_totals!
        end

        schema '$ref' => '#/components/schemas/Order'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('or_')
          expect(data['number']).to eq(guest_order.number)
        end
      end

      response '404', 'order not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { 'or_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '404', 'incomplete order not accessible' do
        let(:incomplete_order) { create(:order_with_line_items, store: store, customer: user) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { incomplete_order.to_param }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
