# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Order Lookups API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:order) { create(:shipped_order, store: store).tap { |order| order.update_columns(email: 'guest@example.com') } }

  path '/api/v3/store/order_lookups' do
    post 'Find an order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC.squish
        "Find my order" for a guest who lost the confirmation email. When the order number and email match an order,
        a link to it is emailed to that address. The answer is always 202, match or not, so it never reveals which
        address placed an order.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      request_body_for

      let(:'x-spree-api-key') { api_key.token }

      response '202', 'lookup accepted' do
        let(:body) { { number: order.number.downcase, email: 'Guest@Example.com' } }

        schema type: :object, properties: { message: { type: :string } }, required: %w[message]

        run_test! do
          expect(Spree::Orders::LookupJob).to have_been_enqueued.with(store.id, order.number.downcase, 'Guest@Example.com')
        end
      end

      response '202', 'lookup accepted for a miss, without saying so' do
        let(:body) { { number: order.number, email: 'someone-else@example.com' } }

        schema type: :object, properties: { message: { type: :string } }, required: %w[message]

        # The match is made in the background, so a miss answers exactly like a
        # match, in the same time.
        run_test! do
          expect(Spree::Orders::LookupJob).to have_been_enqueued.with(store.id, order.number, 'someone-else@example.com')
        end
      end
    end
  end
end
