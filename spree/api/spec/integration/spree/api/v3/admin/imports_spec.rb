# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Imports API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  let!(:product_import) { create(:product_import, owner: store, user: admin_user) }

  def csv_blob(content)
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(content),
      filename: 'import.csv',
      content_type: 'text/csv'
    )
  end

  path '/api/v3/admin/imports' do
    get 'List imports' do
      tags 'Imports'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns CSV imports queued or completed for the current store.'
      admin_scope_note 'the write scope of the imported resource — `write_products` for product imports, `write_customers` for customer imports, etc.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'imports found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].pluck('id')).to include(product_import.prefixed_id)
        end
      end
    end

    post 'Create an import' do
      tags 'Imports'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~MD
        Queues a CSV import. Upload the file first via `POST /api/v3/admin/direct_uploads`
        and pass the returned `signed_id` as `attachment`. On success the import is in the
        `mapping` state and the response carries the mapping payload: `schema_fields`
        (the canonical columns for the type), `csv_headers`, a `sample_row`, and the
        auto-assigned `mappings`.

        Adjust mappings if needed, then call `PATCH /admin/imports/{id}/complete_mapping`
        to start processing. Poll `GET /admin/imports/{id}` while `status` is
        `completed_mapping`/`processing`; terminal statuses are `completed` and `failed`.
      MD
      admin_scope_note 'the write scope of the imported resource — `write_products` for product imports, `write_customers` for customer imports, etc.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[type attachment],
        properties: {
          type: {
            type: :string,
            enum: %w[
              Spree::Imports::Products
              Spree::Imports::Customers
              Spree::Imports::ProductTranslations
            ],
            example: 'Spree::Imports::Products'
          },
          attachment: {
            type: :string,
            description: 'ActiveStorage signed blob id from POST /api/v3/admin/direct_uploads.',
            example: 'eyJfcmFpbHMiOnsiZGF0YSI6MX0=--signed'
          },
          preferred_delimiter: {
            type: :string,
            enum: [',', ';', '|', "\t"],
            description: 'CSV column separator. Defaults to a comma.',
            example: ','
          },
          results_url: {
            type: :string,
            description: 'Absolute URL of your admin imports view; the import-done email links back to it ' \
                         'with `?import=<id>` appended. Only honored when it matches one of the store\'s ' \
                         'configured allowed origins.',
            example: 'https://admin.example.com/store_abc/settings/imports'
          }
        }
      }

      response '201', 'import created in mapping state' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          {
            type: 'Spree::Imports::Products',
            attachment: csv_blob("slug,sku,name,price\nwidget,W-1,Widget,10.00\n").signed_id
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('mapping')
          expect(data['csv_headers']).to eq(%w[slug sku name price])
          expect(data['mappings']).to be_an(Array)
        end
      end

      response '422', 'unknown import type' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { type: 'Spree::Unknown', attachment: csv_blob("slug\nx\n").signed_id } }

        run_test!
      end
    end
  end

  path '/api/v3/admin/imports/template' do
    get 'Download an import template' do
      tags 'Imports'
      produces 'text/csv'
      security [api_key: [], bearer_auth: []]
      description 'Returns a CSV header row for the given import type, including the ' \
                  'custom field columns available for the model.'
      admin_scope_note 'the write scope of the imported resource — `write_products` for product imports, `write_customers` for customer imports, etc.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :type, in: :query, type: :string, required: true,
                description: 'Registered import type, e.g. Spree::Imports::Products.'

      response '200', 'CSV template' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:type) { 'Spree::Imports::Products' }

        schema type: :string, format: :binary

        run_test! do |response|
          expect(response.content_type).to include('text/csv')
          expect(response.body).to start_with('slug,sku,name,price')
        end
      end
    end
  end

  path '/api/v3/admin/imports/{id}' do
    let(:id) { product_import.prefixed_id }

    get 'Show an import' do
      tags 'Imports'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns import status and row counters. The admin dashboard polls this ' \
                  'endpoint while `status` is `completed_mapping` or `processing`; ' \
                  '`rows_count`, `completed_rows_count` and `failed_rows_count` drive the ' \
                  'progress bar. The mapping payload (`csv_headers`, `sample_row`) is only ' \
                  'present while `status` is `mapping`.'
      admin_scope_note 'the write scope of the imported resource — `write_products` for product imports, `write_customers` for customer imports, etc.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'import found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(product_import.prefixed_id)
          expect(data).to include('rows_count', 'completed_rows_count', 'failed_rows_count')
        end
      end
    end

    delete 'Delete an import' do
      tags 'Imports'
      security [api_key: [], bearer_auth: []]
      description 'Removes the import, its rows and the uploaded file. Returns 422 while ' \
                  'the import is being processed.'
      admin_scope_note 'the write scope of the imported resource — `write_products` for product imports, `write_customers` for customer imports, etc.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '204', 'import deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end

  path '/api/v3/admin/imports/{id}/complete_mapping' do
    let(:import_in_mapping) do
      create(:product_import, owner: store, user: admin_user).tap(&:start_mapping!)
    end
    let(:id) { import_in_mapping.prefixed_id }

    patch 'Complete mapping and start processing' do
      tags 'Imports'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~MD
        Applies the submitted column mappings, then starts row processing. Omit `mappings`
        to accept the auto-assigned ones from the create response. Returns 422 when a
        required schema field is left unmapped (`details.missing_required_fields`) or a
        file column is assigned twice.
      MD
      admin_scope_note 'the write scope of the imported resource — `write_products` for product imports, `write_customers` for customer imports, etc.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          mappings: {
            type: :array,
            description: 'Column assignments to apply before starting. `file_column: null` unmaps a field.',
            items: {
              type: :object,
              required: %w[schema_field],
              properties: {
                schema_field: { type: :string, example: 'slug' },
                file_column: { type: :string, nullable: true, example: 'Product Handle' }
              }
            }
          }
        }
      }

      response '200', 'mapping completed, processing queued' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { {} }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('completed_mapping')
        end
      end
    end
  end

  path '/api/v3/admin/imports/{id}/retry_failed_rows' do
    let(:completed_import) do
      create(:product_import, owner: store, user: admin_user).tap do |imp|
        imp.update_columns(status: 'completed')
        create(:import_row, import: imp, row_number: 1, status: 'failed', validation_errors: 'boom')
      end
    end
    let(:id) { completed_import.prefixed_id }

    patch 'Retry failed rows' do
      tags 'Imports'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Re-processes the rows that failed. The import re-enters `processing`; ' \
                  'poll `GET /admin/imports/{id}` until it completes again. Returns 422 ' \
                  'when the import is not `completed` or has no failed rows.'
      admin_scope_note 'the write scope of the imported resource — `write_products` for product imports, `write_customers` for customer imports, etc.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'retry queued' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('processing')
        end
      end
    end
  end

  path '/api/v3/admin/imports/{import_id}/rows' do
    let(:import_id) { product_import.prefixed_id }

    before do
      create(:import_row, import: product_import, row_number: 1, status: 'completed')
      create(:import_row, import: product_import, row_number: 2, status: 'failed', validation_errors: 'boom')
    end

    get 'List import rows' do
      tags 'Imports'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Paginated rows of an import — the failure report. Filter with ' \
                  '`q[status_eq]=failed` to list only rows that could not be imported; ' \
                  'each row carries the raw CSV `data` and its `validation_errors`.'
      admin_scope_note 'the write scope of the imported resource — `write_products` for product imports, `write_customers` for customer imports, etc.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :import_id, in: :path, type: :string, required: true
      parameter name: 'q[status_eq]', in: :query, type: :string, required: false,
                description: 'Filter rows by status: pending, processing, completed, failed.'

      response '200', 'rows found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:'q[status_eq]') { 'failed' }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].size).to eq(1)
          expect(data['data'].first['validation_errors']).to eq('boom')
        end
      end
    end
  end
end
