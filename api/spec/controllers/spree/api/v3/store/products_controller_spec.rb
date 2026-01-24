require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:product) { create(:product, stores: [store], status: 'active') }
  let!(:product2) { create(:product, stores: [store], status: 'active') }
  let!(:draft_product) { create(:product, stores: [store], status: 'draft') }
  let!(:other_store) { create(:store) }
  let!(:other_store_product) { create(:product, stores: [other_store]) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'GET #index' do
    it 'returns a list of products' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(2)
    end

    it 'returns product attributes' do
      get :index

      product_data = json_response['data'].first
      expect(product_data).to include('id', 'name', 'slug')
    end

    it 'returns pagination metadata' do
      get :index, params: { page: 1, per_page: 1 }

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(1)
      expect(json_response['meta']).to include(
        'page' => 1,
        'limit' => 1,
        'count' => 2,
        'pages' => 2
      )
    end

    it 'respects max per_page limit' do
      get :index, params: { per_page: 500 }

      expect(json_response['meta']['limit']).to eq(100)
    end

    context 'store scoping' do
      it 'does not return products from other stores' do
        get :index

        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).not_to include(other_store_product.id)
      end
    end

    context 'status scoping' do
      it 'does not return draft products' do
        get :index

        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).not_to include(draft_product.id)
      end
    end

    context 'ransack filtering' do
      it 'filters products by name' do
        get :index, params: { q: { name_cont: product.name } }

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].size).to eq(1)
        expect(json_response['data'].first['id']).to eq(product.id)
      end
    end

    context 'authentication' do
      context 'without API key' do
        before { request.headers['X-Spree-Api-Key'] = nil }

        it 'returns unauthorized' do
          get :index

          expect(response).to have_http_status(:unauthorized)
          expect(json_response['error']['code']).to eq('invalid_token')
          expect(json_response['error']['message']).to be_present
        end
      end

      context 'with invalid API key' do
        before { request.headers['X-Spree-Api-Key'] = 'invalid' }

        it 'returns unauthorized' do
          get :index

          expect(response).to have_http_status(:unauthorized)
          expect(json_response['error']['code']).to eq('invalid_token')
        end
      end
    end
  end

  describe 'GET #show' do
    it 'returns a product by id' do
      get :show, params: { id: product.id }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(product.id)
      expect(json_response['name']).to eq(product.name)
      expect(json_response['slug']).to eq(product.slug)
    end

    it 'returns a product by slug' do
      get :show, params: { id: product.slug }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(product.id)
    end

    context 'error handling' do
      it 'returns not found for non-existent product' do
        get :show, params: { id: 'non-existent' }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for product from another store' do
        get :show, params: { id: other_store_product.id }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end

      it 'returns not found for draft product' do
        get :show, params: { id: draft_product.id }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end
  end
end
