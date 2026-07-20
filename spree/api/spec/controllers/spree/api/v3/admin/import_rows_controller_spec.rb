require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::ImportRowsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  let(:import) { create(:product_import, owner: store, user: admin_user) }

  let!(:completed_row) { create(:import_row, import: import, row_number: 1, status: 'completed') }
  let!(:failed_row) do
    create(:import_row, import: import, row_number: 2, status: 'failed', validation_errors: "Price can't be blank")
  end

  describe 'GET #index' do
    it 'lists the rows of the import' do
      get :index, params: { import_id: import.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].map { |r| r['id'] }
      expect(ids).to contain_exactly(completed_row.prefixed_id, failed_row.prefixed_id)
    end

    it 'serializes the raw row data and error message' do
      get :index, params: { import_id: import.prefixed_id, q: { status_eq: 'failed' } }, as: :json

      expect(json_response['data'].size).to eq(1)
      row = json_response['data'].first
      expect(row['id']).to eq(failed_row.prefixed_id)
      expect(row['validation_errors']).to eq("Price can't be blank")
      expect(row['data']).to eq('slug' => 'test-product', 'name' => 'Test Product', 'price' => '10.00')
      expect(row['row_number']).to eq(2)
    end

    it 'filters by status via Ransack' do
      get :index, params: { import_id: import.prefixed_id, q: { status_eq: 'completed' } }, as: :json

      ids = json_response['data'].map { |r| r['id'] }
      expect(ids).to contain_exactly(completed_row.prefixed_id)
    end

    it 'returns 404 for an import owned by another store' do
      other_import = create(:product_import, owner: create(:store), user: admin_user)

      get :index, params: { import_id: other_import.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 401 without credentials' do
      request.headers['Authorization'] = nil
      request.headers['x-spree-api-key'] = nil

      get :index, params: { import_id: import.prefixed_id }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
