require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::ExportsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  let!(:product_export) do
    create(:export, type: 'Spree::Exports::Products', store: store, user: admin_user)
  end

  describe 'GET #index' do
    subject { get :index, as: :json }

    it 'returns exports for the current store' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].map { |e| e['id'] }).to include(product_export.prefixed_id)
    end

    it 'omits exports from other stores' do
      other_store = create(:store)
      create(:export, type: 'Spree::Exports::Products', store: other_store, user: admin_user)

      subject
      ids = json_response['data'].map { |e| e['id'] }
      expect(ids).to contain_exactly(product_export.prefixed_id)
    end

    it 'serializes status fields' do
      subject
      row = json_response['data'].find { |e| e['id'] == product_export.prefixed_id }

      expect(row).to include('done' => false, 'download_url' => nil)
      expect(row['type']).to eq('Spree::Exports::Products')
      expect(row['format']).to eq('csv')
    end
  end

  describe 'GET #show' do
    subject { get :show, params: { id: product_export.prefixed_id }, as: :json }

    it 'returns the export' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(product_export.prefixed_id)
      expect(json_response['done']).to eq(false)
    end

    context 'when the export has a generated attachment' do
      before do
        product_export.attachment.attach(
          io: StringIO.new("name,sku\nFoo,FOO-1\n"),
          filename: 'products.csv',
          content_type: 'text/csv'
        )
      end

      it 'reports done with filename and byte_size' do
        subject

        expect(response).to have_http_status(:ok)
        expect(json_response['done']).to eq(true)
        expect(json_response['filename']).to eq('products.csv')
        expect(json_response['byte_size']).to be > 0
      end

      it 'exposes download_url as the API download endpoint path' do
        subject

        expect(json_response['download_url']).to eq(
          "/api/v3/admin/exports/#{product_export.prefixed_id}/download"
        )
      end
    end

    it 'returns 404 for an unknown id' do
      get :show, params: { id: 'exp_unknown' }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'creates a Products export with a Ransack search_params hash' do
      expect {
        post :create,
             params: {
               type: 'Spree::Exports::Products',
               search_params: { name_cont: 'shirt' }
             },
             as: :json
      }.to change(Spree::Export, :count).by(1)

      expect(response).to have_http_status(:created)
      created = Spree::Export.find_by_prefix_id(json_response['id'])
      expect(created).to be_a(Spree::Exports::Products)
      expect(created.user).to eq(admin_user)
      expect(created.store).to eq(store)
      # Model normalizes the hash to a JSON string before persistence
      expect(JSON.parse(created.search_params.to_s)).to eq('name_cont' => 'shirt')
    end

    it 'creates an Orders export' do
      post :create, params: { type: 'Spree::Exports::Orders' }, as: :json

      expect(response).to have_http_status(:created)
      expect(Spree::Export.find_by_prefix_id(json_response['id'])).to be_a(Spree::Exports::Orders)
    end

    it 'creates a Customers export' do
      post :create, params: { type: 'Spree::Exports::Customers' }, as: :json

      expect(response).to have_http_status(:created)
      expect(Spree::Export.find_by_prefix_id(json_response['id'])).to be_a(Spree::Exports::Customers)
    end

    it 'clears search_params when record_selection is "all"' do
      post :create,
           params: {
             type: 'Spree::Exports::Products',
             record_selection: 'all',
             search_params: { name_cont: 'shirt' }
           },
           as: :json

      expect(response).to have_http_status(:created)
      created = Spree::Export.find_by_prefix_id(json_response['id'])
      expect(created.search_params).to be_blank
    end

    it 'rejects unregistered export types' do
      post :create, params: { type: 'Spree::User' }, as: :json

      # Falls back to Spree::Export which fails the `type: presence` validation
      expect(response).to have_http_status(:unprocessable_content)
    end

  end

  describe 'GET #download' do
    subject { get :download, params: { id: product_export.prefixed_id }, as: :json }

    context 'when the export is not done yet' do
      it 'returns 422 with export_not_ready code' do
        subject
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response.dig('error', 'code')).to eq('export_not_ready')
      end
    end

    context 'when the export is done' do
      before do
        product_export.attachment.attach(
          io: StringIO.new("name,sku\nFoo,FOO-1\n"),
          filename: 'products.csv',
          content_type: 'text/csv'
        )
      end

      it 'streams the CSV with attachment disposition' do
        subject

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('text/csv')
        expect(response.headers['Content-Disposition']).to include('attachment')
        expect(response.headers['Content-Disposition']).to include('products.csv')
        expect(response.body).to eq("name,sku\nFoo,FOO-1\n")
      end
    end

    it 'returns 404 for an unknown id' do
      get :download, params: { id: 'exp_unknown' }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, params: { id: product_export.prefixed_id }, as: :json }

    it 'deletes the export' do
      product_export # touch let!
      expect { subject }.to change(Spree::Export, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'authentication' do
    context 'without any credential' do
      let(:headers) { {} }
      subject { get :index, as: :json }

      it 'returns 401 unauthorized' do
        subject
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a secret API key' do
      let(:headers) { api_key_headers }

      it 'allows index with read_exports scope' do
        secret_api_key.update!(scopes: ['read_exports'])
        get :index, as: :json
        expect(response).to have_http_status(:ok)
      end

      it 'allows create with write_exports scope' do
        secret_api_key.update!(scopes: ['write_exports'])
        post :create, params: { type: 'Spree::Exports::Products' }, as: :json
        expect(response).to have_http_status(:created)
      end

      it 'rejects create when the key only has read_exports' do
        secret_api_key.update!(scopes: ['read_exports'])
        post :create, params: { type: 'Spree::Exports::Products' }, as: :json
        expect(response).to have_http_status(:forbidden)
      end

      it 'rejects exports endpoints when the key has only an unrelated scope' do
        secret_api_key.update!(scopes: ['read_orders'])
        get :index, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
