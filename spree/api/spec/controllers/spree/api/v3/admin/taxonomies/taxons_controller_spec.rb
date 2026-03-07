require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Taxonomies::TaxonsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:taxonomy) { create(:taxonomy, store: store) }
  let!(:taxon) { create(:taxon, taxonomy: taxonomy) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns taxons for the taxonomy' do
      get :index, params: { taxonomy_id: taxonomy.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      ids = json_response['data'].map { |t| t['id'] }
      expect(ids).to include(taxon.prefixed_id)
    end

    context 'with taxonomy from another store' do
      let(:other_taxonomy) { create(:taxonomy, store: create(:store)) }

      it 'returns 404' do
        get :index, params: { taxonomy_id: other_taxonomy.prefixed_id }, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET #show' do
    it 'returns the taxon' do
      get :show, params: { taxonomy_id: taxonomy.prefixed_id, id: taxon.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(taxon.prefixed_id)
      expect(json_response['name']).to eq(taxon.name)
    end
  end

  describe 'POST #create' do
    it 'creates a taxon under the taxonomy' do
      expect {
        post :create, params: {
          taxonomy_id: taxonomy.prefixed_id,
          name: 'New Taxon',
          parent_id: taxonomy.root.id
        }, as: :json
      }.to change(taxonomy.taxons, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('New Taxon')
    end
  end

  describe 'PATCH #update' do
    it 'updates the taxon' do
      patch :update, params: {
        taxonomy_id: taxonomy.prefixed_id,
        id: taxon.prefixed_id,
        name: 'Updated Taxon'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Updated Taxon')
      expect(taxon.reload.name).to eq('Updated Taxon')
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the taxon' do
      expect {
        delete :destroy, params: {
          taxonomy_id: taxonomy.prefixed_id,
          id: taxon.prefixed_id
        }, as: :json
      }.to change(taxonomy.taxons, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
