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

    context 'with a results_url' do
      it 'stores it when it matches an allowed origin' do
        create(:allowed_origin, store: store, origin: 'https://admin.example.com')

        post :create,
             params: {
               type: 'Spree::Exports::Products',
               results_url: 'https://admin.example.com/store_abc/exports'
             },
             as: :json

        expect(response).to have_http_status(:created)
        expect(Spree::Export.find_by_prefix_id(json_response['id']).results_url)
          .to eq('https://admin.example.com/store_abc/exports')
      end

      it 'silently drops it when it does not match an allowed origin' do
        post :create,
             params: {
               type: 'Spree::Exports::Products',
               results_url: 'https://evil.example.com/phish'
             },
             as: :json

        expect(response).to have_http_status(:created)
        expect(Spree::Export.find_by_prefix_id(json_response['id']).results_url).to be_nil
      end
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
      # Scopes are fixed at creation (see Spree::ApiKey), so set them on the key
      # rather than mutating after the fact.
      let(:secret_api_key) { create(:api_key, :secret, store: store, scopes: ['read_products']) }

      # No standalone exports scope — each export type is gated by the read
      # scope of the exported resource (Spree::Export.required_scope), so a
      # key can never export data it couldn't read through the API.
      it 'allows creating a Products export with read_products' do
        post :create, params: { type: 'Spree::Exports::Products' }, as: :json
        expect(response).to have_http_status(:created)
      end

      it 'rejects creating a Customers export without read_customers' do
        post :create, params: { type: 'Spree::Exports::Customers' }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['details']['required_scope']).to eq('read_customers')
      end

      it 'filters the index to export types the key can read' do
        customers_export = create(:export, type: 'Spree::Exports::Customers', store: store, user: admin_user)

        get :index, as: :json

        expect(response).to have_http_status(:ok)
        ids = json_response['data'].map { |e| e['id'] }
        expect(ids).to include(product_export.prefixed_id)
        expect(ids).not_to include(customers_export.prefixed_id)
      end

      it 'hides exports of unreadable types from member actions' do
        customers_export = create(:export, type: 'Spree::Exports::Customers', store: store, user: admin_user)

        get :show, params: { id: customers_export.prefixed_id }, as: :json

        expect(response).to have_http_status(:not_found)
      end

      it 'allows downloading an export of a readable type' do
        product_export.attachment.attach(
          io: StringIO.new("name,sku\n"), filename: 'products.csv', content_type: 'text/csv'
        )

        get :download, params: { id: product_export.prefixed_id }, as: :json

        expect(response).to have_http_status(:ok)
      end

      context 'with a promotions-scoped key' do
        let(:secret_api_key) { create(:api_key, :secret, store: store, scopes: ['read_promotions']) }

        it 'gates coupon-code exports by the promotions scope' do
          post :create, params: { type: 'Spree::Exports::CouponCodes' }, as: :json
          expect(response).to have_http_status(:created)
        end
      end
    end
  end
end
