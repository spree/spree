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
  let!(:inactive_product_in_taxon) { create(:product, stores: [store], taxons: [taxon], status: 'draft') }

  let!(:other_store) { create(:store) }
  let!(:other_taxonomy) { create(:taxonomy, store: other_store) }
  let!(:other_taxon) { create(:taxon, taxonomy: other_taxonomy) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'GET #index' do
    context 'finding taxon by permalink' do
      it 'returns active products belonging to the taxon' do
        get :index, params: { taxon_id: taxon.permalink }

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].pluck('id')).to include(product_in_taxon.prefixed_id)
        expect(json_response['data'].pluck('id')).not_to include(product_not_in_taxon.prefixed_id)
        expect(json_response['data'].pluck('id')).not_to include(inactive_product_in_taxon.prefixed_id)
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

    context 'filtering by option values' do
      let(:option_type) { create(:option_type, :color) }
      let(:option_value_red) { create(:option_value, option_type: option_type, name: 'red', presentation: 'Red') }
      let(:option_value_blue) { create(:option_value, option_type: option_type, name: 'blue', presentation: 'Blue') }
      let!(:product_with_red) do
        create(:product, stores: [store], taxons: [taxon], status: 'active', option_types: [option_type]).tap do |p|
          create(:variant, product: p, option_values: [option_value_red], price: 25.0)
        end
      end
      let!(:product_with_blue) do
        create(:product, stores: [store], taxons: [taxon], status: 'active', option_types: [option_type]).tap do |p|
          create(:variant, product: p, option_values: [option_value_blue], price: 75.0)
        end
      end

      it 'filters products by option value prefixed IDs within taxon' do
        get :index, params: { taxon_id: taxon.permalink, q: { with_option_value_ids: [option_value_red.prefixed_id] } }

        expect(response).to have_http_status(:ok)
        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).to include(product_with_red.prefixed_id)
        expect(ids).not_to include(product_with_blue.prefixed_id)
      end

      it 'filters products by price range within taxon' do
        get :index, params: { taxon_id: taxon.permalink, q: { price_between: [50, 100] } }

        expect(response).to have_http_status(:ok)
        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).to include(product_with_blue.prefixed_id)
        expect(ids).not_to include(product_with_red.prefixed_id)
      end

      it 'filters products by option values and price range combined within taxon' do
        get :index, params: { taxon_id: taxon.permalink, q: { with_option_value_ids: [option_value_red.prefixed_id, option_value_blue.prefixed_id], price_between: [50, 100] } }

        expect(response).to have_http_status(:ok)
        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).to include(product_with_blue.prefixed_id)
        expect(ids).not_to include(product_with_red.prefixed_id)
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
