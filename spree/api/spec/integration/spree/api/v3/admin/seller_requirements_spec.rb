# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Seller Requirements API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }

  before { Spree::SellerRequirement.where(store_id: store.id).destroy_all }

  path '/api/v3/admin/seller_requirements' do
    get 'List seller requirements' do
      tags 'Seller Requirements'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        What this marketplace asks of a seller before it will let them trade,
        in the order sellers work through it.

        Each row is one configured requirement. `required` says whether it
        stands between the seller and approval — the others are shown as
        recommended and counted in their progress, but never block. `active`
        switches one off without losing how it was worded.
      DESC
      admin_scope :read, :sellers

      admin_sdk_example 'seller_requirements/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :limit, in: :query, type: :integer, required: false

      response '200', 'seller requirements found' do
        let!(:requirement) { create(:accept_terms_requirement, store: store) }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/SellerRequirement' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               }

        run_test!
      end
    end

    post 'Add a seller requirement' do
      tags 'Seller Requirements'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Adds something the marketplace asks of its sellers.

        `type` comes from `GET /seller_requirements/types`, which also
        describes the configuration each kind takes. Most kinds answer one
        question and can be added once; the open-ended ones — a seller
        confirmation, a manual check, a document — carry the question in your
        own `name` and `description`, so a store may add as many as it needs.

        A kind that reads the seller's own data (their addresses, their
        products, whether they accepted the terms) needs nothing from the
        seller beyond doing it. The others wait for the seller to submit
        something, and the ones you review wait for you.
      DESC
      admin_scope :write, :sellers

      admin_sdk_example 'seller_requirements/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[type],
        properties: {
          type: { type: :string, example: 'document',
                  description: 'The kind, from `GET /seller_requirements/types`.' },
          name: { type: :string, example: 'Business registration',
                  description: 'What the seller sees. Required for kinds that can be added more than ' \
                               'once, since the wording is the only thing telling them apart. Left ' \
                               'blank on the others, the kind names itself.' },
          description: { type: :string, example: 'A copy of your certificate of incorporation.',
                         description: 'Instructions shown to the seller.' },
          required: { type: :boolean, example: true,
                      description: 'Whether this blocks approval. Off means recommended.' },
          active: { type: :boolean, example: true },
          position: { type: :integer, example: 1, description: 'Place in the checklist.' },
          preferences: { type: :object, example: { accepted_content_types: ['application/pdf'] },
                         description: 'Configuration for this kind, per its `preference_schema`.' }
        }
      }

      response '201', 'seller requirement created' do
        let(:body) { { type: 'document', name: 'Business registration', required: true } }

        schema '$ref' => '#/components/schemas/SellerRequirement'

        run_test!
      end

      response '422', 'kind is not registered' do
        let(:body) { { type: 'imaginary_check' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/seller_requirements/types' do
    get 'List seller requirement kinds' do
      tags 'Seller Requirements'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        The kinds you can add, and the shape of each one's configuration form.

        `configured` says the store already has this kind — meaningful only
        where `allow_multiple` is false. `accepts_submissions` says the seller
        records having done it rather than it being read from their data, and
        `reviewed_by_operator` says what they send waits for you.

        A marketplace that registers its own kind server-side sees it here
        without this endpoint changing.
      DESC
      admin_scope :read, :sellers

      admin_sdk_example 'seller_requirements/types'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'kinds found' do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       type: { type: :string, example: 'document' },
                       name: { type: :string, example: 'Document' },
                       description: { type: :string, example: 'A file the seller uploads and you review' },
                       allow_multiple: { type: :boolean, example: true },
                       accepts_submissions: { type: :boolean, example: true },
                       reviewed_by_operator: { type: :boolean, example: true },
                       configured: { type: :boolean, example: false },
                       addable: { type: :boolean, example: true,
                                  description: 'Whether the operator may add one now. The uniqueness ' \
                                               'rule is the server\'s, so clients filter on this rather ' \
                                               'than deriving it.' },
                       preference_schema: { type: :array, items: { type: :object } }
                     }
                   }
                 }
               }

        run_test!
      end
    end
  end

  path '/api/v3/admin/seller_requirements/{id}' do
    parameter name: :id, in: :path, type: :string, required: true

    patch 'Update a seller requirement' do
      tags 'Seller Requirements'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Changes how a requirement is worded, what it asks for, where it sits in
        the checklist, and whether it blocks approval.

        `type` is not accepted: a saved row's kind never changes, because
        anything a seller already submitted answered the old one.
      DESC
      admin_scope :write, :sellers

      admin_sdk_example 'seller_requirements/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Proof of business registration' },
          description: { type: :string, example: 'A copy of your certificate of incorporation.' },
          required: { type: :boolean, example: false },
          active: { type: :boolean, example: true },
          position: { type: :integer, example: 2 },
          preferences: { type: :object, example: { minimum_count: 3 } }
        }
      }

      response '200', 'seller requirement updated' do
        let(:requirement) { create(:minimum_products_requirement, store: store) }
        let(:id) { requirement.prefixed_id }
        let(:body) { { preferences: { minimum_count: 3 } } }

        schema '$ref' => '#/components/schemas/SellerRequirement'

        run_test!
      end
    end

    delete 'Delete a seller requirement' do
      tags 'Seller Requirements'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Stops asking for this. Anything sellers already submitted against it
        goes too — to keep the record while pausing the ask, set `active` to
        false instead.
      DESC
      admin_scope :write, :sellers

      admin_sdk_example 'seller_requirements/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '204', 'seller requirement deleted' do
        let(:requirement) { create(:accept_terms_requirement, store: store) }
        let(:id) { requirement.prefixed_id }

        run_test!
      end
    end
  end
end
