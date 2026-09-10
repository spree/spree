require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::SuppliersController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:store) { Spree::Store.default }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    let!(:supplier) { create(:supplier, store: store, name: 'Acme Wholesale') }

    it 'returns the store’s suppliers' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |s| s['name'] }).to include('Acme Wholesale')
    end

    it "never lists another store's suppliers" do
      foreign = create(:supplier, store: create(:store))

      get :index, as: :json

      expect(json_response['data'].map { |s| s['id'] }).not_to include(foreign.prefixed_id)
    end

    it 'omits soft-deleted suppliers' do
      supplier.destroy

      get :index, as: :json

      expect(json_response['data'].map { |s| s['id'] }).not_to include(supplier.prefixed_id)
    end
  end

  describe 'POST #create' do
    let(:params) do
      {
        name: 'Acme Wholesale',
        contact_name: 'Dana Okafor',
        email: 'Sales@Acme.test',
        phone: '555-0100',
        address1: '1 Warehouse Way',
        city: 'Brooklyn',
        state_code: 'NY',
        country_code: 'US',
        postal_code: '11201'
      }
    end

    it 'creates a supplier against the current store' do
      expect { post :create, params: params, as: :json }.to change(Spree::Supplier, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response).to include('name' => 'Acme Wholesale', 'email' => 'sales@acme.test',
                                       'city' => 'Brooklyn', 'country_code' => 'US')
      expect(Spree::Supplier.last.store).to eq(store)
    end

    it 'returns 422 without a name' do
      post :create, params: params.except(:name), as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 422 for a name already in use in this store' do
      create(:supplier, store: store, name: 'Acme Wholesale')

      post :create, params: params, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    let!(:supplier) { create(:supplier, store: store) }

    it 'edits the supplier' do
      patch :update, params: { id: supplier.prefixed_id, contact_name: 'Sam Reyes' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['contact_name']).to eq('Sam Reyes')
    end

    it "returns 404 for another store's supplier" do
      foreign = create(:supplier, store: create(:store))

      patch :update, params: { id: foreign.prefixed_id, contact_name: 'Sam Reyes' }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE #destroy' do
    let!(:supplier) { create(:supplier, store: store) }

    it 'soft-deletes the supplier' do
      delete :destroy, params: { id: supplier.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(supplier.reload.deleted_at).to be_present
    end

    # The purchasing history has to keep naming who it was with.
    it 'refuses while purchase orders still point at it' do
      create(:purchase_order, store: store, supplier: supplier)

      delete :destroy, params: { id: supplier.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(supplier.reload.deleted_at).to be_nil
    end
  end
end
