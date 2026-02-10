require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::TaxonomiesController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:taxonomy) { create(:taxonomy, store: store) }
  let!(:taxonomy2) { create(:taxonomy, store: store) }
  let!(:other_store) { create(:store) }
  let!(:other_store_taxonomy) { create(:taxonomy, store: other_store) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'GET #index' do
    it 'returns taxonomies' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to be >= 2
    end

    it 'returns taxonomy attributes' do
      get :index

      taxonomy_data = json_response['data'].first
      expect(taxonomy_data).to include('id', 'name')
    end

    it 'does not return taxonomies from other stores' do
      get :index

      ids = json_response['data'].map { |t| t['id'] }
      expect(ids).not_to include(other_store_taxonomy.prefix_id)
    end

    it 'returns pagination metadata' do
      get :index

      expect(json_response['meta']).to include('page', 'count', 'pages')
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_token')
        expect(json_response['error']['message']).to be_present
      end
    end
  end

  describe 'GET #show' do
    it 'returns the taxonomy' do
      get :show, params: { id: taxonomy.prefix_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(taxonomy.prefix_id)
      expect(json_response['name']).to eq(taxonomy.name)
    end

    it 'returns taxonomy with its attributes' do
      get :show, params: { id: taxonomy.prefix_id }

      expect(json_response['id']).to eq(taxonomy.prefix_id)
      expect(json_response['name']).to be_present
    end

    it 'returns root_id for quick access to root taxon' do
      get :show, params: { id: taxonomy.prefix_id }

      expect(json_response['root_id']).to eq(taxonomy.root.prefix_id)
    end

    context 'error handling' do
      it 'returns not found for non-existent taxonomy' do
        get :show, params: { id: 'txnmy_nonexistent' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for taxonomy from another store' do
        get :show, params: { id: other_store_taxonomy.prefix_id }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end
  end
end
