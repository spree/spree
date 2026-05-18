# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Gift Card Batches API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:batch) { create(:gift_card_batch, store: store, prefix: 'WELCOME', amount: 50, currency: 'USD', codes_count: 2) }

  path '/api/v3/admin/gift_card_batches' do
    get 'List gift card batches' do
      tags 'Gift Cards'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns the gift card batches issued by the current store. Each batch
        groups the cards generated together for a campaign or bulk-issuance
        — the cards themselves live under `/admin/gift_cards` and reference
        the batch via `gift_card_batch_id`.
      DESC
      admin_scope :read, :gift_cards

      admin_sdk_example 'gift-card-batches/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page'
      parameter name: :'q[prefix_cont]', in: :query, type: :string, required: false,
                description: 'Filter by prefix (contains)'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort by field. Prefix with `-` for descending.'

      response '200', 'gift card batches found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('GiftCardBatch')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(batch.prefixed_id)
        end
      end
    end

    post 'Create a gift card batch' do
      tags 'Gift Cards'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Issues a batch of gift cards in a single call. The server generates
        `codes_count` cards inline for small batches (configurable via
        `Spree.config.gift_card_batch_web_limit`, default 500) or enqueues
        a background job for larger ones. Each card's code is the batch
        `prefix` followed by random hex.
      DESC
      admin_scope :write, :gift_cards

      admin_sdk_example 'gift-card-batches/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[prefix amount codes_count],
        properties: {
          prefix: { type: :string, example: 'WELCOME', description: 'Lowercased and prepended to every generated code.' },
          amount: { type: :string, example: '25.00', description: 'Decimal amount per card, greater than zero.' },
          currency: { type: :string, example: 'USD', description: 'ISO 4217 currency code. Defaults to the store currency.' },
          codes_count: { type: :integer, example: 100, description: 'Number of cards to generate. Capped at `gift_card_batch_limit`.' },
          expires_at: { type: :string, example: '2030-12-31', nullable: true }
        }
      }

      response '201', 'gift card batch created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { prefix: 'NEWCAMP', amount: '25.00', currency: 'USD', codes_count: 5, expires_at: '2030-12-31' } }

        schema '$ref' => '#/components/schemas/GiftCardBatch'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['prefix']).to eq('NEWCAMP')
          expect(data['codes_count']).to eq(5)
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { prefix: '', amount: '25.00', codes_count: 5 } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/gift_card_batches/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Gift card batch prefixed ID'

    get 'Get a gift card batch' do
      tags 'Gift Cards'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single batch.'
      admin_scope :read, :gift_cards

      admin_sdk_example 'gift-card-batches/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'gift card batch found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { batch.prefixed_id }

        schema '$ref' => '#/components/schemas/GiftCardBatch'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(batch.prefixed_id)
        end
      end

      response '404', 'gift card batch not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'gcb_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
