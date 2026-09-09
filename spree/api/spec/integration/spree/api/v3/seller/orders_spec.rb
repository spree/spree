# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Orders API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  # The seeded role rather than the shared context's products-only one —
  # orders are gated on the `orders` permission, which that role omits.
  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end

  let!(:order) { create(:completed_order_with_totals, store: store, seller: seller) }

  path '/api/v3/seller/orders' do
    get 'List orders' do
      tags 'Orders'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        What this seller has sold.

        On a marketplace a basket spanning several sellers is split into one
        order each, so these are the seller's own orders rather than a filtered
        view of somebody else's — another seller's order is never reachable,
        whatever id is sent.

        Checkouts still in flight are left out: until one completes it is
        nobody's order.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'
      parameter name: :sort, in: :query, type: :string, required: false, description: 'Sort field; prefix with `-` for descending'

      response '200', 'orders listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Order' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |item| item['number'] }).to include(order.number)
        end
      end
    end
  end

  path '/api/v3/seller/orders/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Prefixed order ID'

    get 'Get an order' do
      tags 'Orders'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        One order, as the seller needs it to pack and post the parcel: the
        lines with their SKUs, where it ships to, and a fulfillment per parcel.

        How the customer paid the marketplace is deliberately absent — that is
        between the buyer and the operator.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'order found' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { order.prefixed_id }

        schema '$ref' => '#/components/schemas/Order'

        run_test! do |response|
          expect(JSON.parse(response.body)['number']).to eq(order.number)
        end
      end

      response '404', "another seller's order" do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) do
          create(:completed_order_with_totals,
                 store: store, seller: create(:seller, :approved, store: store)).prefixed_id
        end

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/seller/orders/{id}/cancel' do
    parameter name: :id, in: :path, type: :string, description: 'Prefixed order ID'

    patch 'Cancel an order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Withdraws from an order this seller cannot fulfil, naming a reason from
        the marketplace's own list.

        The goods go back on the shelf and the payment authorization is
        released either way. `refund_payments` also hands back what the buyer
        paid for these goods — a seller is merchant of record for their own
        child order, and on a split checkout only that order's share of the
        group's payment is settled.

        There is no `refund_amount`: withdrawing from the whole order returns
        what that order was paid, and a partial figure is a return.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          cancel_reason_id: {
            type: :string,
            nullable: true,
            description: 'A reason from GET /order_cancellation_reasons'
          },
          cancel_note: { type: :string, nullable: true, description: 'Free text beside the reason' },
          refund_payments: {
            type: :boolean,
            description: "Hand back what the buyer paid for this order's goods"
          },
          notify_customer: { type: :boolean, description: 'Email the customer about the cancellation' }
        }
      }

      response '200', 'order canceled' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { order.prefixed_id }
        let(:body) { {} }

        schema '$ref' => '#/components/schemas/Order'

        run_test! do
          expect(order.reload).to be_canceled
        end
      end
    end
  end

  path '/api/v3/seller/orders/{id}/address' do
    parameter name: :id, in: :path, type: :string, description: 'Prefixed order ID'

    patch 'Correct an order address' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Corrects where the goods go or who the invoice names.

        The seller is merchant of record for their own child order, so a
        delivery address the buyer got wrong is theirs to fix. Send only the
        lines that change — the rest of the address is carried over.

        This is the only write against the order itself besides cancelling:
        nothing else about it, its totals included, is the seller's to change.
      DESC

      address_correction = {
        type: :object,
        description: 'Only the lines that change; the rest is carried over',
        properties: {
          first_name: { type: :string },
          last_name: { type: :string },
          company: { type: :string, nullable: true },
          address1: { type: :string },
          address2: { type: :string, nullable: true },
          city: { type: :string },
          postal_code: { type: :string },
          country_code: { type: :string },
          state_code: { type: :string, nullable: true },
          state_name: { type: :string, nullable: true },
          phone: { type: :string, nullable: true },
          label: { type: :string, nullable: true }
        }
      }

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          shipping_address: address_correction,
          billing_address: address_correction
        }
      }

      response '200', 'address corrected' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { order.prefixed_id }
        let(:body) { { shipping_address: { address1: '9 Corrected Way', city: 'Fixedton' } } }

        schema '$ref' => '#/components/schemas/Order'

        run_test! do
          expect(order.reload.ship_address.city).to eq('Fixedton')
        end
      end

      response '422', 'neither address named' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { order.prefixed_id }
        let(:body) { {} }

        run_test!
      end
    end
  end

  path '/api/v3/seller/orders/{order_id}/notes' do
    parameter name: :order_id, in: :path, type: :string, description: 'Prefixed order ID'

    get 'Get order notes' do
      tags 'Orders'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        The instructions the buyer left, and the seller's own working note.

        A marketplace basket splits into one order per seller, so the internal
        note here is this seller's alone rather than the operator's note about
        the whole sale.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'notes' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }

        schema '$ref' => '#/components/schemas/Order'

        run_test!
      end
    end

    patch 'Update order notes' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Send only the note that changes: an absent key leaves the other alone,
        while an empty string clears it.

        `internal_note` accepts HTML and is sanitized on save;
        `internal_note_html` reads it back.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          customer_note: {
            type: :string,
            nullable: true,
            description: "What the buyer asked for"
          },
          internal_note: {
            type: :string,
            nullable: true,
            description: "The seller's own working note, as HTML"
          }
        }
      }

      response '200', 'notes updated' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:body) { { internal_note: '<p>Packed with the fragile insert.</p>' } }

        schema '$ref' => '#/components/schemas/Order'

        run_test! do
          expect(order.reload.internal_note.to_s).to include('fragile insert')
        end
      end

      response '422', 'neither note named' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:body) { {} }

        run_test!
      end
    end
  end

  path '/api/v3/seller/order_cancellation_reasons' do
    get 'List order cancellation reasons' do
      tags 'Orders'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Why an order was called off, as the marketplace defines it.

        Read-only: a seller picks one when cancelling, and the operator decides
        what the list holds. Retired reasons are left out.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'reasons listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        before { create(:order_cancellation_reason, store: store, name: 'Out of stock') }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Reason' } }
               },
               required: %w[data]

        run_test!
      end
    end
  end
end
