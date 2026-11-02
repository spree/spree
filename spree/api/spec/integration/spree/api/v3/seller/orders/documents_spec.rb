# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Order Documents API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end

  let(:Authorization) { "Bearer #{seller_jwt_token}" }
  let(:'X-Spree-Seller-Id') { seller.prefixed_id }
  let!(:order) { create(:shipped_order, store: store, seller: seller, line_items_count: 1) }
  let(:order_id) { order.prefixed_id }
  let!(:document) { create(:order_document, order: order) }

  path '/api/v3/seller/orders/{order_id}/documents/{id}' do
    parameter name: :order_id, in: :path, type: :string, required: true
    parameter name: :id, in: :path, type: :string, required: true

    patch 'Update an order document' do
      tags 'Order Documents'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Renames a document the seller's own team uploaded, or changes whether the buyer sees it."
      seller_sdk_example 'order-documents/update'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for

      response '200', "the seller's own document" do
        let(:own) { create(:order_document, order: order, uploaded_by: seller_user) }
        let(:id) { own.prefixed_id }
        let(:body) { { customer_visible: true } }

        schema '$ref' => '#/components/schemas/OrderDocument'

        run_test! { expect(own.reload.customer_visible).to be(true) }
      end

      response '404', "the operator's document" do
        let(:id) { document.prefixed_id }
        let(:body) { { customer_visible: true } }

        run_test! { expect(document.reload.customer_visible).to be(false) }
      end
    end

    delete 'Delete an order document' do
      tags 'Order Documents'
      security [bearer_auth: []]
      description "Only a document the seller's own team uploaded: the operator's and the buyer's paperwork stay."
      seller_sdk_example 'order-documents/delete'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '204', "the seller's own document" do
        let(:id) { create(:order_document, order: order, uploaded_by: seller_user).prefixed_id }

        run_test!
      end

      response '404', "the operator's document" do
        let(:id) { document.prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/seller/orders/{order_id}/documents' do
    parameter name: :order_id, in: :path, type: :string, required: true

    get "List an order's documents" do
      tags 'Order Documents'
      produces 'application/json'
      security [bearer_auth: []]
      seller_sdk_example 'order-documents/list'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      filter_parameters_for

      response '200', 'documents listed' do
        schema type: :object,
               properties: { data: { type: :array, items: { '$ref' => '#/components/schemas/OrderDocument' } } },
               required: %w[data]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.first['download_url']).to eq("/api/v3/seller/orders/#{order.prefixed_id}/documents/#{document.prefixed_id}/download")
        end
      end
    end

    post 'Upload an order document' do
      tags 'Order Documents'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      seller_sdk_example 'order-documents/create'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for

      response '201', 'document uploaded' do
        let(:blob) do
          ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF-1.4\n%%EOF\n"), filename: 'cmr.pdf',
                                                 content_type: 'application/pdf', service_name: Spree.private_storage_service_name)
        end
        let(:body) { { label: 'CMR consignment note', file_signed_id: blob.signed_id } }

        schema '$ref' => '#/components/schemas/OrderDocument'

        run_test!
      end
    end
  end
end
