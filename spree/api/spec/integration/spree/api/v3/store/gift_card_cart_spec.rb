# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Cart Gift Card API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:order) { create(:order_with_line_items, store: store, user: user) }
  let(:cart_id) { order.prefixed_id }

  path '/api/v3/store/carts/{cart_id}/gift_cards' do
    post 'Apply gift card' do
      tags 'Carts'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Applies a gift card to the cart. Gift cards are treated as a payment method, not a discount —
        the cart `total` remains unchanged while `amount_due` is reduced.

        For promotion discount codes, use the `POST /carts/{cart_id}/discount_codes` endpoint instead.
      DESC

      sdk_example 'carts/gift-cards-apply'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Order token for guest access'
      parameter name: :cart_id, in: :path, type: :string, required: true, description: 'Cart prefixed ID (e.g., cart_abc123)'
      parameter name: 'Idempotency-Key', in: :header, type: :string, required: false,
                description: 'Unique key for request idempotency.'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          code: { type: :string, example: 'GC-ABCD-1234', description: 'Gift card code to apply' }
        },
        required: %w[code]
      }

      response '201', 'gift card applied' do
        let!(:gift_card) { create(:gift_card, store: store, amount: 50, code: 'giftcode1') }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { code: 'giftcode1' } }

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('cart_')
          expect(data['gift_card_total']).to be_present
          expect(data['amount_due']).to be_present
        end
      end

      response '404', 'gift card not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { code: 'NONEXISTENT' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.dig('error', 'code')).to eq('gift_card_not_found')
        end
      end

      response '422', 'gift card expired' do
        let!(:gift_card) { create(:gift_card, store: store, amount: 50, code: 'expiredgc', expires_at: 1.day.ago) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { code: 'expiredgc' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.dig('error', 'code')).to eq('gift_card_expired')
        end
      end

      response '422', 'gift card already redeemed' do
        let!(:gift_card) { create(:gift_card, store: store, amount: 50, code: 'redeemedgc', amount_used: 50, state: :redeemed, redeemed_at: Time.current) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { code: 'redeemedgc' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.dig('error', 'code')).to eq('gift_card_already_redeemed')
        end
      end
    end
  end

  path '/api/v3/store/carts/{cart_id}/gift_cards/{id}' do
    delete 'Remove gift card' do
      tags 'Carts'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Removes a previously applied gift card from the cart.'

      sdk_example 'carts/gift-cards-remove'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: :cart_id, in: :path, type: :string, required: true, description: 'Cart prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Gift card prefixed ID (e.g., gc_abc123)'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Order token for guest access'

      response '200', 'gift card removed' do
        let!(:gift_card) { create(:gift_card, store: store, amount: 50, code: 'removegc') }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) do
          order.apply_gift_card(gift_card)
          gift_card.prefixed_id
        end

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('cart_')
        end
      end
    end
  end
end
