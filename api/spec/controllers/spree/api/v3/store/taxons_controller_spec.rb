require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::TaxonsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:taxonomy) { create(:taxonomy, store: store) }
  let!(:taxon) { create(:taxon, taxonomy: taxonomy) }
  let!(:child_taxon) { create(:taxon, taxonomy: taxonomy, parent: taxon) }
  let!(:other_store) { create(:store) }
  let!(:other_taxonomy) { create(:taxonomy, store: other_store) }
  let!(:other_store_taxon) { create(:taxon, taxonomy: other_taxonomy) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'GET #show' do
    it 'returns the taxon' do
      get :show, params: { id: taxon.id }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(taxon.id)
      expect(json_response['name']).to eq(taxon.name)
    end

    it 'returns taxon attributes' do
      get :show, params: { id: taxon.id }

      expect(json_response).to include('id', 'name', 'permalink')
    end

    it 'includes parent information' do
      get :show, params: { id: child_taxon.id }

      expect(response).to have_http_status(:ok)
    end

    context 'error handling' do
      it 'returns not found for non-existent taxon' do
        get :show, params: { id: 0 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for taxon from another store' do
        get :show, params: { id: other_store_taxon.id }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end

      it 'returns not found for invalid id' do
        get :show, params: { id: 'invalid' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        get :show, params: { id: taxon.id }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_token')
        expect(json_response['error']['message']).to be_present
      end
    end
  end
end
