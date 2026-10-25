# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Products API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let!(:product) { create(:product, store: store, seller: seller) }

  path '/api/v3/seller/products' do
    get 'List products' do
      tags 'Products'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        The seller's own catalog — the products they own outright.

        Every call is rooted in the acting seller server-side, so this can never
        return another seller's product or one the marketplace operator sells
        first-party.
      DESC

      seller_sdk_example 'products/list'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'
      parameter name: :sort, in: :query, type: :string, required: false, description: 'Sort field; prefix with `-` for descending'
      filter_parameters_for

      response '200', 'products listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Product' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |item| item['id'] }).to include(product.prefixed_id)
        end
      end
    end

    post 'Create a product' do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Creates a product owned by the acting seller.

        The seller and the store are taken from the request context whatever the
        payload says, so a product cannot be created against another seller.

        The operator's own settings — tax category, delivery profile and whether
        the product is promotionable — are not writable here; they belong to the
        marketplace, not the seller.
      DESC

      seller_sdk_example 'products/create'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for

      response '201', 'product created' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) { { name: 'Hand-thrown mug', prices: [{ amount: '24.00', currency: 'USD' }] } }

        schema '$ref' => '#/components/schemas/Product'

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('Hand-thrown mug')
        end
      end

      response '422', 'validation failed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/seller/products/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Product ID'

    get 'Get a product' do
      tags 'Products'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        A product the acting seller owns.

        An id belonging to another seller answers `404`, not `403` — the seller
        is not told the record exists.
      DESC

      seller_sdk_example 'products/get'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'product returned' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { product.prefixed_id }

        schema '$ref' => '#/components/schemas/Product'

        run_test!
      end

      response '404', "another seller's product" do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:other_seller) { create(:seller, :approved, store: store) }
        let(:id) { create(:product, store: store, seller: other_seller).prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a product' do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Edits a product the acting seller owns.'

      seller_sdk_example 'products/update'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for

      response '200', 'product updated' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { product.prefixed_id }
        let(:body) { { name: 'Hand-thrown mug, large' } }

        schema '$ref' => '#/components/schemas/Product'

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('Hand-thrown mug, large')
        end
      end
    end

    delete 'Delete a product' do
      tags 'Products'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Deletes a product the acting seller owns.'

      seller_sdk_example 'products/delete'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '204', 'product deleted' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { product.prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/seller/products/{id}/submit' do
    parameter name: :id, in: :path, type: :string, description: 'Product ID'

    patch 'Submit a product for review' do
      tags 'Products'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Asks the marketplace to put a product on sale. Whether a listing goes
        live is the operator's decision, so a seller submits it for review
        rather than setting its status. Only drafts and rejected listings can
        be submitted.

        Where the marketplace approves seller products automatically, the
        product comes back already `active`.
      DESC

      seller_sdk_example 'products/submit'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'product submitted' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { create(:product, store: store, seller: seller, status: 'draft').prefixed_id }

        schema '$ref' => '#/components/schemas/Product'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('proposed')
        end
      end

      response '422', 'product cannot be submitted' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { product.prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/seller/products/{id}/draft' do
    parameter name: :id, in: :path, type: :string, description: 'Product ID'

    patch 'Move a product back to draft' do
      tags 'Products'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Takes a listing down. Withdrawing your own product is not a review
        decision, so it needs nobody's approval.
      DESC

      seller_sdk_example 'products/draft'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'product moved to draft' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { product.prefixed_id }

        schema '$ref' => '#/components/schemas/Product'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('draft')
        end
      end
    end
  end

  path '/api/v3/seller/products/{id}/archive' do
    parameter name: :id, in: :path, type: :string, description: 'Product ID'

    patch 'Archive a product' do
      tags 'Products'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Retires a product the acting seller owns, taking it off sale without deleting it.'

      seller_sdk_example 'products/archive'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'product archived' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { product.prefixed_id }

        schema '$ref' => '#/components/schemas/Product'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('archived')
        end
      end
    end
  end

  path '/api/v3/seller/products/bulk_submit' do
    post 'Submit products for review' do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Submits a selection for the marketplace to review. Only drafts and
        rejected listings can be submitted, so a mixed selection moves what it
        can: `product_count` is what was submitted, and `skipped_count`, present
        only when something was skipped, is the rest.
      DESC

      seller_sdk_example 'products/bulk-submit'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for

      response '200', 'products submitted' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let!(:draft) { create(:product, store: store, seller: seller, status: 'draft') }
        let(:body) { { ids: [draft.prefixed_id] } }

        run_test! do |response|
          expect(JSON.parse(response.body)['product_count']).to eq(1)
        end
      end
    end
  end

  path '/api/v3/seller/products/bulk_status_update' do
    post 'Change the status of products' do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Moves a selection to `draft` or `archived`. There is no bulk route onto
        `active`: a listing goes on sale when the marketplace approves it.
      DESC

      seller_sdk_example 'products/bulk-status-update'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for

      response '200', 'statuses changed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) { { ids: [product.prefixed_id], status: 'archived' } }

        run_test! do |response|
          expect(JSON.parse(response.body)['product_count']).to eq(1)
        end
      end
    end
  end

  path '/api/v3/seller/products/bulk_destroy' do
    delete 'Delete products' do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Deletes a selection of the acting seller's products. Ids outside this
        seller's catalog are ignored. A product the marketplace refuses to
        delete is skipped: `product_count` is what was deleted, and
        `skipped_count`, present only when something was skipped, is the rest.
      DESC

      seller_sdk_example 'products/bulk-destroy'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for

      response '200', 'products deleted' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) { { ids: [product.prefixed_id] } }

        run_test! do |response|
          expect(JSON.parse(response.body)['product_count']).to eq(1)
        end
      end
    end
  end
end
