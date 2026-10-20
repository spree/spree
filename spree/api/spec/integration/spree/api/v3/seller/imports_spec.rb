# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Imports API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let!(:product_import) { create(:product_import, store: store, seller: seller, user: seller_user) }

  def csv_blob(content)
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(content),
      filename: 'import.csv',
      content_type: 'text/csv'
    )
  end

  path '/api/v3/seller/imports' do
    get 'List imports' do
      tags 'Imports'
      produces 'application/json'
      security [bearer_auth: []]
      description "This seller's product CSV imports, queued or finished. Another seller's imports are never listed."

      seller_sdk_example 'imports/list'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'
      filter_parameters_for

      response '200', 'imports listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        before { create(:product_import, :for_seller, store: store) }

        schema SwaggerSchemaHelpers.paginated('Import')

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |item| item['id'] }).to eq([product_import.prefixed_id])
        end
      end
    end

    post 'Create an import' do
      tags 'Imports'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Starts a product CSV import for this seller. Upload the CSV with `POST /files`
        (`visibility: 'private'`) and pass the returned `signed_id` as
        `attachment_signed_id`. On success the import is in the `mapping` state, carrying
        the auto-assigned column `mappings`; confirm them with
        `PATCH /imports/{id}/complete_mapping`. Imported products are created as drafts.
      DESC

      seller_sdk_example 'imports/create'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for

      response '201', 'import created in mapping state' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) do
          {
            type: 'products',
            attachment_signed_id: csv_blob("slug,sku,name,price\nwidget,W-1,Widget,10.00\n").signed_id
          }
        end

        schema SwaggerSchemaHelpers.ref('Import')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('mapping')
          expect(Spree::Import.find_by_prefix_id(data['id']).seller).to eq(seller)
        end
      end
    end
  end

  path '/api/v3/seller/imports/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Import prefixed ID'

    get 'Get an import' do
      tags 'Imports'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        One of this seller's imports. Poll it while `status` is `completed_mapping`
        or `processing`; `completed` and `failed` are final. An id belonging to
        another seller answers `404`.
      DESC

      seller_sdk_example 'imports/get'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'import returned' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { product_import.prefixed_id }

        schema SwaggerSchemaHelpers.ref('Import')

        run_test! do |response|
          expect(JSON.parse(response.body)['id']).to eq(product_import.prefixed_id)
        end
      end

      response '404', "another seller's import" do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { create(:product_import, :for_seller, store: store).prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    delete 'Delete an import' do
      tags 'Imports'
      produces 'application/json'
      security [bearer_auth: []]
      description "Deletes one of this seller's imports together with its rows. Products it already created are kept."

      seller_sdk_example 'imports/delete'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '204', 'import deleted' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { product_import.prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/seller/imports/{import_id}/rows' do
    parameter name: :import_id, in: :path, type: :string, required: true, description: 'Import prefixed ID'

    get 'List import rows' do
      tags 'Imports'
      produces 'application/json'
      security [bearer_auth: []]
      description "The rows of one of this seller's imports, each with its status and any validation errors."

      seller_sdk_example 'imports/rows-list'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'
      filter_parameters_for

      response '200', 'rows listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:import_id) { product_import.prefixed_id }
        let!(:import_row) { create(:import_row, import: product_import) }

        schema SwaggerSchemaHelpers.paginated('ImportRow')

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |item| item['id'] }).to eq([import_row.prefixed_id])
        end
      end
    end
  end

  path '/api/v3/seller/imports/{id}/complete_mapping' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Import prefixed ID'

    patch 'Complete mapping and start processing' do
      tags 'Imports'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Applies the submitted column mappings, then starts row processing. Omit `mappings`
        to accept the auto-assigned ones from the create response. Returns 422 when a
        required field is left unmapped (`details.missing_required_fields`).
      DESC

      seller_sdk_example 'imports/complete-mapping'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for(required: false)

      response '200', 'mapping completed, processing queued' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) do
          product_import.tap { |import| Spree.import_start_mapping_workflow.call(import: import) }.prefixed_id
        end
        let(:body) { { mappings: [{ schema_field: 'name', file_column: 'name' }] } }

        schema SwaggerSchemaHelpers.ref('Import')

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('completed_mapping')
        end
      end
    end
  end

  path '/api/v3/seller/imports/{id}/retry_failed_rows' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Import prefixed ID'

    patch 'Retry failed rows' do
      tags 'Imports'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Processes the rows that failed again, typically after fixing what they
        referred to. The import goes back to `processing`; poll
        `GET /imports/{id}` until it finishes. Returns 422 when the import has
        no failed rows to retry.
      DESC

      seller_sdk_example 'imports/retry-failed-rows'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'retry queued' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) do
          product_import.tap do |import|
            import.update_columns(status: 'completed')
            create(:import_row, import: import, row_number: 1, status: 'failed', validation_errors: 'Price is missing')
          end.prefixed_id
        end

        schema SwaggerSchemaHelpers.ref('Import')

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('processing')
        end
      end

      response '422', 'no failed rows to retry' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { product_import.prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/seller/imports/{id}/download' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Import prefixed ID'

    get 'Download the uploaded file' do
      tags 'Imports'
      produces 'text/csv'
      security [bearer_auth: []]
      description <<~DESC
        Streams the CSV exactly as the seller uploaded it — a record of what was
        imported.

        The bytes are served by this endpoint rather than through a redirect,
        so the seller's own session authorizes every download.
      DESC

      seller_sdk_example 'imports/download'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'CSV file' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { product_import.prefixed_id }

        schema type: :string, format: :binary

        run_test! do |response|
          expect(response.content_type).to include('text/csv')
        end
      end
    end
  end
end
