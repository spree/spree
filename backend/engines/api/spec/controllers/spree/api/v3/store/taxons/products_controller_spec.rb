require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Taxons::ProductsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:taxonomy) { create(:taxonomy, store: store) }
  let!(:taxon) { create(:taxon, taxonomy: taxonomy) }
  let!(:child_taxon) { create(:taxon, taxonomy: taxonomy, parent: taxon) }

  let!(:product_in_taxon) { create(:product, stores: [store], taxons: [taxon]) }
  let!(:product_in_child_taxon) { create(:product, stores: [store], taxons: [child_taxon]) }
  let!(:product_not_in_taxon) { create(:product, stores: [store]) }

  let!(:other_store) { create(:store) }
  let!(:other_taxonomy) { create(:taxonomy, store: other_store) }
  let!(:other_taxon) { create(:taxon, taxonomy: other_taxonomy) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'GET #index' do
    context 'finding taxon by permalink' do
      it 'returns products belonging to the taxon' do
        get :index, params: { taxon_id: taxon.permalink }

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].pluck('id')).to include(product_in_taxon.prefixed_id)
        expect(json_response['data'].pluck('id')).not_to include(product_not_in_taxon.prefixed_id)
      end

      it 'returns products from descendant taxons' do
        get :index, params: { taxon_id: taxon.permalink }

        expect(response).to have_http_status(:ok)
        # Parent taxon should include products from child taxons
        expect(json_response['data'].pluck('id')).to include(product_in_taxon.prefixed_id)
        expect(json_response['data'].pluck('id')).to include(product_in_child_taxon.prefixed_id)
      end

      it 'returns only products from the specific child taxon when queried directly' do
        get :index, params: { taxon_id: child_taxon.permalink }

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].pluck('id')).to include(product_in_child_taxon.prefixed_id)
        expect(json_response['data'].pluck('id')).not_to include(product_in_taxon.prefixed_id)
      end
    end

    context 'finding taxon by prefix_id' do
      it 'returns products belonging to the taxon' do
        get :index, params: { taxon_id: taxon.prefixed_id }

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].pluck('id')).to include(product_in_taxon.prefixed_id)
      end
    end

    it 'returns pagination metadata' do
      get :index, params: { taxon_id: taxon.permalink }

      expect(json_response['meta']).to include('page', 'limit', 'count', 'pages')
    end

    it 'supports pagination' do
      create_list(:product, 3, stores: [store], taxons: [taxon])

      get :index, params: { taxon_id: taxon.permalink, per_page: 2, page: 1 }

      expect(json_response['data'].size).to eq(2)
      expect(json_response['meta']['page']).to eq(1)
      expect(json_response['meta']['pages']).to be > 1
    end

    context 'error handling' do
      it 'returns not found for non-existent taxon' do
        get :index, params: { taxon_id: 'non-existent' }

        expect(response).to have_http_status(:not_found)
      end

      it 'returns not found for taxon from another store' do
        get :index, params: { taxon_id: other_taxon.permalink }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        get :index, params: { taxon_id: taxon.permalink }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'sorting' do
      let!(:cheap_product) do
        create(:product, stores: [store], taxons: [taxon], status: 'active', name: 'Cheap').tap do |p|
          p.master.prices.first.update!(amount: 10.0)
        end
      end

      let!(:expensive_product) do
        create(:product, stores: [store], taxons: [taxon], status: 'active', name: 'Expensive').tap do |p|
          p.master.prices.first.update!(amount: 100.0)
        end
      end

      it 'sorts by price low to high' do
        get :index, params: { taxon_id: taxon.permalink, q: { sort_by: 'price-low-to-high' } }

        expect(response).to have_http_status(:ok)
        prices = json_response['data'].map { |p| p['price']['amount'].to_f }
        expect(prices).to eq(prices.sort)
      end

      it 'sorts by price high to low' do
        get :index, params: { taxon_id: taxon.permalink, q: { sort_by: 'price-high-to-low' } }

        expect(response).to have_http_status(:ok)
        prices = json_response['data'].map { |p| p['price']['amount'].to_f }
        expect(prices).to eq(prices.sort.reverse)
      end

      it 'sorts by name a-z with ransack' do
        get :index, params: { taxon_id: taxon.permalink, q: { s: 'name asc' } }

        expect(response).to have_http_status(:ok)
        names = json_response['data'].map { |p| p['name'] }
        expect(names).to eq(names.sort)
      end
    end
  end
end
