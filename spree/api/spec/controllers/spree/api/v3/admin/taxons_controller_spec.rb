require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::TaxonsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:taxonomy) { create(:taxonomy, store: store) }
  let!(:taxon) { create(:taxon, taxonomy: taxonomy) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns all taxons' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      ids = json_response['data'].map { |t| t['id'] }
      expect(ids).to include(taxon.prefixed_id)
    end
  end

  describe 'GET #show' do
    it 'returns the taxon' do
      get :show, params: { id: taxon.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(taxon.prefixed_id)
      expect(json_response['name']).to eq(taxon.name)
    end

    it 'returns 404 for non-existent taxon' do
      get :show, params: { id: 'taxon_nonexistent' }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
