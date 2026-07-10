require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::ImportsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  def csv_signed_id(content, filename: 'import.csv')
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(content),
      filename: filename,
      content_type: 'text/csv'
    ).signed_id
  end

  let!(:product_import) { create(:product_import, owner: store, user: admin_user) }

  describe 'GET #index' do
    subject { get :index, as: :json }

    it 'returns imports for the current store' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |i| i['id'] }).to include(product_import.prefixed_id)
    end

    it 'omits imports owned by other stores' do
      other_import = create(:product_import, owner: create(:store), user: admin_user)

      subject
      ids = json_response['data'].map { |i| i['id'] }
      expect(ids).to include(product_import.prefixed_id)
      expect(ids).not_to include(other_import.prefixed_id)
    end
  end

  describe 'GET #show' do
    context 'while processing' do
      before do
        product_import.update_columns(status: 'processing')
        create(:import_row, import: product_import, row_number: 1, status: 'completed')
        create(:import_row, import: product_import, row_number: 2, status: 'completed')
        create(:import_row, import: product_import, row_number: 3, status: 'failed', validation_errors: 'boom')
      end

      it 'returns poll counters without the mapping payload' do
        get :show, params: { id: product_import.prefixed_id }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['status']).to eq('processing')
        expect(json_response['rows_count']).to eq(3)
        expect(json_response['completed_rows_count']).to eq(2)
        expect(json_response['failed_rows_count']).to eq(1)
        # Blob-reading attributes are mapping-state only
        expect(json_response['csv_headers']).to eq([])
        expect(json_response['sample_row']).to eq({})
      end
    end

    it 'returns 404 for an unknown id' do
      get :show, params: { id: 'imp_unknown' }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'creates a Products import from a signed blob id and advances into mapping' do
      expect {
        post :create,
             params: {
               type: 'Spree::Imports::Products',
               attachment: csv_signed_id("slug,sku,name,price\nwidget,W-1,Widget,10.00\n")
             },
             as: :json
      }.to change(Spree::Import, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['status']).to eq('mapping')
      expect(json_response['type']).to eq('Spree::Imports::Products')
      expect(json_response['csv_headers']).to eq(%w[slug sku name price])
      expect(json_response['sample_row']).to eq(
        'slug' => 'widget', 'sku' => 'W-1', 'name' => 'Widget', 'price' => '10.00'
      )

      slug_field = json_response['schema_fields'].find { |f| f['name'] == 'slug' }
      expect(slug_field['required']).to eq(true)

      slug_mapping = json_response['mappings'].find { |m| m['schema_field'] == 'slug' }
      expect(slug_mapping['file_column']).to eq('slug')

      created = Spree::Import.find_by_prefix_id(json_response['id'])
      expect(created.user).to eq(admin_user)
      expect(created.owner).to eq(store)
    end

    it 'accepts a preferred delimiter' do
      post :create,
           params: {
             type: 'Spree::Imports::Products',
             preferred_delimiter: ';',
             attachment: csv_signed_id("slug;sku;name;price\nwidget;W-1;Widget;10.00\n")
           },
           as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['preferred_delimiter']).to eq(';')
      expect(json_response['csv_headers']).to eq(%w[slug sku name price])
    end

    it 'rejects unregistered import types' do
      post :create, params: { type: 'Spree::User', attachment: csv_signed_id("slug\nx\n") }, as: :json

      # Falls back to Spree::Import which fails the `type` presence validation
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects an invalid attachment signed id' do
      post :create, params: { type: 'Spree::Imports::Products', attachment: 'not-a-signed-id' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a non-CSV attachment' do
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('{}'), filename: 'import.json', content_type: 'application/json'
      )

      post :create, params: { type: 'Spree::Imports::Products', attachment: blob.signed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'marks the import failed when the CSV is unparseable' do
      post :create,
           params: {
             type: 'Spree::Imports::Products',
             attachment: csv_signed_id("slug,\"sku\nbroken")
           },
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(Spree::Import.last.status).to eq('failed')
      expect(Spree::Import.last.processing_errors).to be_present
    end
  end

  describe 'PATCH #complete_mapping' do
    let(:import) do
      create(:product_import, owner: store, user: admin_user).tap do |imp|
        imp.attachment.attach(
          io: StringIO.new(csv_content), filename: 'import.csv', content_type: 'text/csv'
        )
        imp.start_mapping!
      end
    end

    context 'when every required field auto-mapped' do
      let(:csv_content) { "slug,sku,name,price\nwidget,W-1,Widget,10.00\n" }

      it 'transitions into completed_mapping and enqueues row creation' do
        expect {
          patch :complete_mapping, params: { id: import.prefixed_id }, as: :json
        }.to have_enqueued_job(Spree::Imports::CreateRowsJob)

        expect(response).to have_http_status(:ok)
        expect(json_response['status']).to eq('completed_mapping')
      end
    end

    context 'when a required column needs manual mapping' do
      let(:csv_content) { "Product Handle,sku,name,price\nwidget,W-1,Widget,10.00\n" }

      it 'applies submitted mappings before completing' do
        patch :complete_mapping,
              params: {
                id: import.prefixed_id,
                mappings: [{ schema_field: 'slug', file_column: 'Product Handle' }]
              },
              as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['status']).to eq('completed_mapping')
        expect(import.mappings.find_by(schema_field: 'slug').file_column).to eq('Product Handle')
      end

      it 'returns 422 listing missing required fields when left unmapped' do
        patch :complete_mapping, params: { id: import.prefixed_id }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response.dig('error', 'details', 'missing_required_fields')).to eq(['slug'])
        expect(import.reload.status).to eq('mapping')
      end
    end

    context 'when a file column is assigned twice' do
      let(:csv_content) { "slug,sku,name,price\nwidget,W-1,Widget,10.00\n" }

      it 'returns 422 with the mapping validation error' do
        patch :complete_mapping,
              params: {
                id: import.prefixed_id,
                mappings: [{ schema_field: 'description', file_column: 'sku' }]
              },
              as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    it 'returns 422 when the import is not in the mapping state' do
      product_import.update_columns(status: 'processing')

      patch :complete_mapping, params: { id: product_import.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #retry_failed_rows' do
    before { product_import.update_columns(status: 'completed') }

    context 'with failed rows' do
      before do
        create(:import_row, import: product_import, row_number: 1, status: 'failed', validation_errors: 'boom')
      end

      it 're-enters processing and re-dispatches the rows' do
        expect {
          patch :retry_failed_rows, params: { id: product_import.prefixed_id }, as: :json
        }.to have_enqueued_job(Spree::Imports::ProcessRowsJob)

        expect(response).to have_http_status(:ok)
        expect(json_response['status']).to eq('processing')
      end
    end

    it 'returns 422 when there are no failed rows' do
      patch :retry_failed_rows, params: { id: product_import.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(product_import.reload.status).to eq('completed')
    end
  end

  describe 'GET #template' do
    it 'returns a CSV header row for the type schema' do
      get :template, params: { type: 'Spree::Imports::Products' }

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/csv')
      expect(response.headers['Content-Disposition']).to include('products_import_template.csv')
      expect(response.body).to start_with('slug,sku,name,price')
    end

    it 'returns 422 for an unknown type' do
      get :template, params: { type: 'Spree::User' }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes a completed import' do
      product_import.update_columns(status: 'completed')

      expect {
        delete :destroy, params: { id: product_import.prefixed_id }, as: :json
      }.to change(Spree::Import, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'refuses to delete a processing import' do
      product_import.update_columns(status: 'processing')

      delete :destroy, params: { id: product_import.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(product_import.reload).to be_present
    end
  end

  describe 'authentication' do
    context 'without any credential' do
      let(:headers) { {} }

      it 'returns 401 unauthorized' do
        get :index, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a secret API key' do
      let(:headers) { api_key_headers }
      let(:secret_api_key) { create(:api_key, :secret, store: store, scopes: ['write_products'], created_by: admin_user) }

      it 'allows creating a Products import with write_products, attributed to the key creator' do
        post :create,
             params: {
               type: 'Spree::Imports::Products',
               attachment: csv_signed_id("slug,sku,name,price\nwidget,W-1,Widget,10.00\n")
             },
             as: :json

        expect(response).to have_http_status(:created)
        expect(Spree::Import.find_by_prefix_id(json_response['id']).user).to eq(admin_user)
      end

      it 'rejects creating a Customers import without write_customers' do
        post :create, params: { type: 'Spree::Imports::Customers', attachment: csv_signed_id("email\nx@y.com\n") }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['details']['required_scope']).to eq('write_customers')
      end

      it 'filters the index to import types the key can write' do
        customers_import = create(:customer_import, owner: store, user: admin_user)

        get :index, as: :json

        ids = json_response['data'].map { |i| i['id'] }
        expect(ids).to include(product_import.prefixed_id)
        expect(ids).not_to include(customers_import.prefixed_id)
      end

      it 'hides imports of unwritable types from member actions' do
        customers_import = create(:customer_import, owner: store, user: admin_user)

        get :show, params: { id: customers_import.prefixed_id }, as: :json

        expect(response).to have_http_status(:not_found)
      end

      context 'when the key has no admin creator' do
        let(:secret_api_key) { create(:api_key, :secret, store: store, scopes: ['write_products']) }

        it 'rejects create with a user presence error' do
          post :create,
               params: {
                 type: 'Spree::Imports::Products',
                 attachment: csv_signed_id("slug,sku,name,price\nwidget,W-1,Widget,10.00\n")
               },
               as: :json

          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end
  end
end
