# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Exports API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:product_export) do
    create(:export, type: 'Spree::Exports::Products', store: store, user: admin_user)
  end

  path '/api/v3/admin/exports' do
    get 'List exports' do
      tags 'Exports'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns CSV exports queued or completed for the current store. ' \
                  'Polled by the admin SPA to detect when an export finishes (`done: true`).'
      admin_scope :read, :exports

      admin_sdk_example <<~JS
        const { data: exports } = await client.exports.list()
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'exports found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].pluck('id')).to include(product_export.prefixed_id)
        end
      end
    end

    post 'Create an export' do
      tags 'Exports'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~MD
        Queues a CSV export. The `type` selects the dataset; `search_params` is an
        optional Ransack query (same shape used by the `q[...]` params on list endpoints)
        that filters which records are exported. Pass `record_selection: "all"` to
        clear the filter server-side and export everything in scope.

        Generation is asynchronous. Poll `GET /admin/exports/{id}` until `done` is `true`,
        then redirect the browser to `download_url` to fetch the file.
      MD
      admin_scope :write, :exports

      admin_sdk_example <<~JS
        const exp = await client.exports.create({
          type: 'Spree::Exports::Products',
          search_params: { name_cont: 'shirt' }
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[type],
        properties: {
          type: {
            type: :string,
            enum: %w[
              Spree::Exports::Products
              Spree::Exports::Orders
              Spree::Exports::Customers
              Spree::Exports::ProductTranslations
              Spree::Exports::GiftCards
              Spree::Exports::CouponCodes
              Spree::Exports::NewsletterSubscribers
            ],
            example: 'Spree::Exports::Products'
          },
          record_selection: {
            type: :string,
            enum: %w[filtered all],
            description: 'Set to "all" to ignore search_params and export everything in scope.',
            example: 'filtered'
          },
          search_params: {
            type: :object,
            description: 'Ransack query hash. Same predicates accepted by the list endpoint.',
            example: { name_cont: 'shirt' },
            additionalProperties: true
          }
        }
      }

      response '201', 'export queued' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { type: 'Spree::Exports::Products', search_params: { name_cont: 'shirt' } } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['type']).to eq('Spree::Exports::Products')
          expect(data['done']).to eq(false)
        end
      end
    end
  end

  path '/api/v3/admin/exports/{id}' do
    let(:id) { product_export.prefixed_id }

    get 'Show an export' do
      tags 'Exports'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns export status. While `done` is `false`, the SPA continues polling.'
      admin_scope :read, :exports

      admin_sdk_example <<~JS
        const exp = await client.exports.get('exp_xxx')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'export found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(product_export.prefixed_id)
        end
      end
    end

    delete 'Delete an export' do
      tags 'Exports'
      security [api_key: [], bearer_auth: []]
      description 'Removes the export and purges its attachment.'
      admin_scope :write, :exports

      admin_sdk_example <<~JS
        await client.exports.delete('exp_xxx')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '204', 'export deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end

  path '/api/v3/admin/exports/{id}/download' do
    let(:id) { product_export.prefixed_id }

    before do
      product_export.attachment.attach(
        io: StringIO.new("name,sku\nFoo,FOO-1\n"),
        filename: 'products.csv',
        content_type: 'text/csv'
      )
    end

    get 'Download an export' do
      tags 'Exports'
      produces 'text/csv'
      security [api_key: [], bearer_auth: []]
      description 'Streams the exported CSV with `Content-Disposition: attachment`. ' \
                  'Returns 422 with `code: export_not_ready` while `done` is still ' \
                  '`false`. The endpoint is JWT/API-key protected, so SPA clients ' \
                  'must fetch it (with `Authorization` header) and trigger the ' \
                  'browser download via a Blob URL — a top-level navigation cannot ' \
                  'carry the JWT.'
      admin_scope :read, :exports

      admin_sdk_example <<~JS
        // Fetch with the Bearer token, then drive the browser download:
        const res = await fetch(exp.download_url, {
          headers: { Authorization: `Bearer ${token}` }
        })
        const blob = await res.blob()
        const url = URL.createObjectURL(blob)
        const a = Object.assign(document.createElement('a'), {
          href: url,
          download: exp.filename
        })
        a.click()
        URL.revokeObjectURL(url)
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'CSV file' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        produces 'text/csv'
        schema type: :string, format: :binary

        run_test! do |response|
          expect(response.content_type).to include('text/csv')
          expect(response.headers['Content-Disposition']).to include('attachment')
        end
      end
    end
  end
end
