require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::TaxonomiesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:taxonomy) { create(:taxonomy, store: store) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns taxonomies for the current store' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      ids = json_response['data'].map { |t| t['id'] }
      expect(ids).to include(taxonomy.prefixed_id)
    end

    it 'does not return taxonomies from other stores' do
      other_taxonomy = create(:taxonomy, store: create(:store))

      get :index, as: :json

      ids = json_response['data'].map { |t| t['id'] }
      expect(ids).not_to include(other_taxonomy.prefixed_id)
    end
  end

  describe 'GET #show' do
    it 'returns the taxonomy' do
      get :show, params: { id: taxonomy.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(taxonomy.prefixed_id)
      expect(json_response['name']).to eq(taxonomy.name)
    end

    it 'returns 404 for non-existent taxonomy' do
      get :show, params: { id: 'tax_nonexistent' }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'creates a taxonomy' do
      post :create, params: { name: 'New Taxonomy' }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('New Taxonomy')
    end

    context 'with invalid params' do
      it 'returns validation errors' do
        post :create, params: { name: '' }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'PATCH #update' do
    it 'updates the taxonomy' do
      patch :update, params: { id: taxonomy.prefixed_id, name: 'Updated Name' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Updated Name')
      expect(taxonomy.reload.name).to eq('Updated Name')
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the taxonomy' do
      expect {
        delete :destroy, params: { id: taxonomy.prefixed_id }, as: :json
      }.to change(Spree::Taxonomy, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
