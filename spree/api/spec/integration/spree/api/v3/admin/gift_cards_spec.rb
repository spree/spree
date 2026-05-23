# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Gift Cards API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:gift_card) { create(:gift_card, store: store, amount: 50, currency: 'USD') }
  let!(:other_card) { create(:gift_card, store: store, amount: 25, currency: 'USD') }

  path '/api/v3/admin/gift_cards' do
    get 'List gift cards' do
      tags 'Gift Cards'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns the gift cards issued by the current store. Filter by
        `q[code_cont]` for code search, `q[user_id_eq]` for cards issued
        to a specific customer, or `q[state_eq]` for status filtering.
      DESC
      admin_scope :read, :gift_cards

      admin_sdk_example 'gift-cards/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[code_cont]', in: :query, type: :string, required: false,
                description: 'Filter by gift card code (contains)'
      parameter name: :'q[state_eq]', in: :query, type: :string, required: false,
                description: 'Filter by status (active, redeemed, partially_redeemed, canceled)'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort by field. Prefix with `-` for descending (e.g., `-created_at`).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'gift cards found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('GiftCard')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          ids = data['data'].pluck('id')
          expect(ids).to include(gift_card.prefixed_id, other_card.prefixed_id)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a gift card' do
      tags 'Gift Cards'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Issues a gift card scoped to the current store. The code is
        auto-generated when omitted. `currency` defaults to the store's
        configured currency. Pass `user_id` (prefixed ID) to attach the
        card to a specific customer.
      DESC
      admin_scope :write, :gift_cards

      admin_sdk_example 'gift-cards/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[amount],
        properties: {
          amount: { type: :string, example: '25.00', description: 'Decimal amount, greater than zero.' },
          currency: { type: :string, example: 'USD', description: 'ISO 4217 currency code. Defaults to the store currency.' },
          code: { type: :string, example: 'WELCOME50', description: 'Optional caller-supplied code. Auto-generated when omitted.' },
          expires_at: { type: :string, example: '2030-12-31', description: 'ISO 8601 date.', nullable: true },
          user_id: { type: :string, example: 'cus_UkLWZg9DAJ', description: 'Optional customer prefixed ID.', nullable: true }
        }
      }

      response '201', 'gift card created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { amount: '25.00', currency: 'USD', expires_at: '2030-12-31' } }

        schema '$ref' => '#/components/schemas/GiftCard'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['display_amount']).to match(/\$25\.00/)
          expect(data['status']).to eq('active')
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { amount: '0', currency: 'USD' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/gift_cards/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Gift card prefixed ID'

    get 'Get a gift card' do
      tags 'Gift Cards'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single gift card.'
      admin_scope :read, :gift_cards

      admin_sdk_example 'gift-cards/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'gift card found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { gift_card.prefixed_id }

        schema '$ref' => '#/components/schemas/GiftCard'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(gift_card.prefixed_id)
        end
      end

      response '404', 'gift card not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'gc_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a gift card' do
      tags 'Gift Cards'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Updates an active gift card's editable attributes. Redeemed or
        partially-redeemed cards cannot be edited.
      DESC
      admin_scope :write, :gift_cards

      admin_sdk_example 'gift-cards/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          amount: { type: :string, example: '75.00' },
          expires_at: { type: :string, example: '2031-12-31', nullable: true },
          user_id: { type: :string, example: 'cus_UkLWZg9DAJ', nullable: true }
        }
      }

      response '200', 'gift card updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { gift_card.prefixed_id }
        let(:body) { { amount: '75.00' } }

        schema '$ref' => '#/components/schemas/GiftCard'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['display_amount']).to match(/\$75\.00/)
        end
      end
    end

    delete 'Delete a gift card' do
      tags 'Gift Cards'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Deletes an unused gift card. Cards that have been redeemed or
        partially redeemed cannot be deleted and return 422.
      DESC
      admin_scope :write, :gift_cards

      admin_sdk_example 'gift-cards/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'gift card deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { gift_card.prefixed_id }

        run_test!
      end

      response '422', 'redeemed gift card cannot be deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:redeemed_gift_card) { create(:gift_card, :redeemed, store: store, amount: 100) }
        let(:id) { redeemed_gift_card.prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
