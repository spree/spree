# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Offers API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let!(:master) do
    create(:product, name: 'Shared Lamp', store: store, status: 'active', open_to_sellers: true)
  end
  let!(:location) { create(:stock_location, store: store, seller: seller) }
  let!(:offer) do
    create(:variant, product: master, seller: seller, sku: 'OFFER-1', status: 'draft').tap do |variant|
      variant.set_price('USD', 9.99)
    end
  end

  path '/api/v3/seller/master_products' do
    get 'List the marketplace catalog' do
      tags 'Offers'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        The marketplace's own products a seller may list an offer against.

        Read only, and only the products the operator has opened to sellers —
        a product is closed until they say otherwise. Serialized exactly as
        the storefront sees it, so a seller compares the offers already on a
        product without seeing a rival's costs or warehouses.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'

      response '200', 'catalog listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       name: { type: :string },
                       slug: { type: :string }
                     },
                     required: %w[id name slug]
                   }
                 },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |item| item['id'] }).to include(master.prefixed_id)
        end
      end
    end
  end

  path '/api/v3/seller/master_products/{master_product_id}/variants' do
    post 'List an offer' do
      tags 'Offers'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Lists this seller's own offer against one of the marketplace's
        products.

        The offer opens as a draft: putting it on sale is the marketplace's
        decision, asked for with `submit`. Name a value for every option type
        the product is sold by, chosen from the values it already carries.
        Stock levels naming a warehouse that is not this seller's are ignored.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :master_product_id, in: :path, type: :string, required: true,
                description: 'Master product ID'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          sku: { type: :string },
          prices: {
            type: :array,
            items: {
              type: :object,
              properties: {
                amount: { type: :string },
                currency: { type: :string }
              }
            }
          },
          stock_levels: {
            type: :array,
            items: {
              type: :object,
              properties: {
                stock_location_id: { type: :string },
                count_on_hand: { type: :integer }
              }
            }
          }
        }
      }

      response '201', 'offer listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:master_product_id) { master.prefixed_id }
        let(:body) do
          {
            sku: 'OFFER-NEW',
            prices: [{ amount: '12.50', currency: 'USD' }],
            stock_levels: [{ stock_location_id: location.prefixed_id, count_on_hand: 4 }]
          }
        end

        schema '$ref' => '#/components/schemas/Variant'

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['sku']).to eq('OFFER-NEW')
          expect(json['status']).to eq('draft')
        end
      end
    end
  end

  path '/api/v3/seller/variants' do
    get 'List your offers' do
      tags 'Offers'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Every offer this seller holds, across the marketplace's catalog.

        Rooted in the seller, so another seller's offer on the same product is
        never listed and its id answers 404. Expand `product` to name what
        each offer sits on.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'

      response '200', 'offers listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Variant' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |item| item['sku'] }).to include('OFFER-1')
        end
      end
    end
  end

  path '/api/v3/seller/variants/{id}' do
    patch 'Update an offer' do
      tags 'Offers'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Edits this seller's own offer.

        `status` and `seller_id` are not writable: an offer changes hands
        never, and it goes on sale by being approved.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true, description: 'Offer (variant) ID'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: { sku: { type: :string }, barcode: { type: :string } }
      }

      response '200', 'offer updated' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { offer.prefixed_id }
        let(:body) { { sku: 'OFFER-EDITED' } }

        schema '$ref' => '#/components/schemas/Variant'

        run_test! do |response|
          expect(JSON.parse(response.body)['sku']).to eq('OFFER-EDITED')
        end
      end
    end
  end

  path '/api/v3/seller/variants/{id}/submit' do
    patch 'Submit an offer for review' do
      tags 'Offers'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Asks the marketplace to put this offer on sale.

        An offer needs a price before it can be submitted. Where the store
        approves offers automatically it goes straight on sale; otherwise it
        waits as `proposed` until the operator decides.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true, description: 'Offer (variant) ID'

      response '200', 'offer submitted' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { offer.prefixed_id }

        schema '$ref' => '#/components/schemas/Variant'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('proposed')
        end
      end

      response '422', 'offer has no price' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) do
          create(:variant, product: master, seller: seller, status: 'draft').tap do |variant|
            variant.prices.destroy_all
          end.prefixed_id
        end

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
