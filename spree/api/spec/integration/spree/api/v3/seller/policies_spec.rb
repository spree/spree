# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Policies API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end

  let!(:policy) do
    create(:policy, owner: seller, name: 'Returns Policy', slug: 'returns-policy',
                    body: '<p>Send anything back within 30 days.</p>')
  end

  path '/api/v3/seller/policies' do
    get 'List policies' do
      tags 'Policies'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        This seller's own policy documents.

        Rooted in the acting seller, so the marketplace operator's store
        policies and every other seller's are invisible here. A seller starts
        with none: what they are expected to publish is decided by the
        marketplace's onboarding checklist.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'

      response '200', 'policies listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Policy' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |item| item['id'] }).to include(policy.prefixed_id)
        end
      end
    end

    post 'Create a policy' do
      tags 'Policies'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Publishes one of this seller's policies. `body` accepts HTML and is
        sanitized before it is stored.

        When the marketplace requires a named policy, use that exact name —
        the onboarding check matches on it.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Shipping Policy' },
          slug: { type: :string, example: 'shipping-policy' },
          body: { type: :string, example: '<p>Orders leave the workshop within two working days.</p>' }
        },
        required: %w[name]
      }

      response '201', 'policy created' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) do
          { name: 'Shipping Policy', body: '<p>Orders leave the workshop within two working days.</p>' }
        end

        schema '$ref' => '#/components/schemas/Policy'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Shipping Policy')
        end
      end
    end
  end

  path '/api/v3/seller/policies/{id}' do
    parameter name: :id, in: :path, type: :string, required: true,
              description: 'Policy prefixed ID or slug'

    get 'Get a policy' do
      tags 'Policies'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Returns one of this seller\'s policies, by prefixed ID or slug.'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'policy found' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { policy.prefixed_id }

        schema '$ref' => '#/components/schemas/Policy'

        run_test! do |response|
          expect(JSON.parse(response.body)['id']).to eq(policy.prefixed_id)
        end
      end

      response '404', 'policy not found' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { 'pol_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a policy' do
      tags 'Policies'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Rewrites one of this seller\'s policies.'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          slug: { type: :string },
          body: { type: :string }
        }
      }

      response '200', 'policy updated' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { policy.prefixed_id }
        let(:body) { { body: '<p>Send anything back within 60 days.</p>' } }

        schema '$ref' => '#/components/schemas/Policy'

        run_test! do |response|
          expect(JSON.parse(response.body)['body_html']).to include('60 days')
        end
      end
    end

    delete 'Delete a policy' do
      tags 'Policies'
      security [bearer_auth: []]
      description 'Withdraws one of this seller\'s policies.'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '204', 'policy deleted' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { policy.prefixed_id }

        run_test!
      end
    end
  end
end
