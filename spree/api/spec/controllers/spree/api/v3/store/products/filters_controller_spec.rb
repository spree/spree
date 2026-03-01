require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Products::FiltersController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:taxonomy) { create(:taxonomy, store: store) }
  let!(:taxon) { create(:taxon, taxonomy: taxonomy) }
  let!(:child_taxon1) { create(:taxon, taxonomy: taxonomy, parent: taxon, name: 'Shirts') }
  let!(:child_taxon2) { create(:taxon, taxonomy: taxonomy, parent: taxon, name: 'Pants') }

  let(:option_type_size) { create(:option_type, name: 'size', presentation: 'Size', filterable: true, position: 1) }
  let(:option_type_color) { create(:option_type, name: 'color', presentation: 'Color', filterable: true, position: 2) }
  let(:option_value_small) { create(:option_value, option_type: option_type_size, name: 'small', presentation: 'S', position: 1) }
  let(:option_value_medium) { create(:option_value, option_type: option_type_size, name: 'medium', presentation: 'M', position: 2) }
  let(:option_value_red) { create(:option_value, option_type: option_type_color, name: 'red', presentation: 'Red', position: 1) }
  let(:option_value_blue) { create(:option_value, option_type: option_type_color, name: 'blue', presentation: 'Blue', position: 2) }

  let!(:product1) do
    create(:product, stores: [store], status: 'active', taxons: [child_taxon1]).tap do |p|
      p.option_types << option_type_size
      p.option_types << option_type_color
      create(:variant, product: p, option_values: [option_value_small, option_value_red])
    end
  end

  let!(:product2) do
    create(:product, stores: [store], status: 'active', taxons: [child_taxon1]).tap do |p|
      p.option_types << option_type_size
      create(:variant, product: p, option_values: [option_value_medium])
    end
  end

  let!(:product3) do
    create(:product, stores: [store], status: 'active', taxons: [child_taxon2]).tap do |p|
      p.option_types << option_type_color
      create(:variant, product: p, option_values: [option_value_blue])
    end
  end

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'GET #index' do
    it 'returns filter metadata' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response).to have_key('filters')
      expect(json_response).to have_key('sort_options')
      expect(json_response).to have_key('default_sort')
      expect(json_response).to have_key('total_count')
    end

    it 'returns price filter' do
      get :index

      price_filter = json_response['filters'].find { |f| f['type'] == 'price_range' }
      expect(price_filter).to be_present
      expect(price_filter['id']).to eq('price')
      expect(price_filter).to have_key('min')
      expect(price_filter).to have_key('max')
      expect(price_filter).to have_key('currency')
    end

    it 'returns availability filter' do
      get :index

      availability_filter = json_response['filters'].find { |f| f['type'] == 'availability' }
      expect(availability_filter).to be_present
      expect(availability_filter['options']).to include(
        hash_including('id' => 'in_stock'),
        hash_including('id' => 'out_of_stock')
      )
    end

    it 'returns option type filters with counts' do
      get :index

      size_filter = json_response['filters'].find { |f| f['name'] == 'size' }
      expect(size_filter).to be_present
      expect(size_filter['type']).to eq('option')
      expect(size_filter['presentation']).to eq('Size')

      size_options = size_filter['options']
      expect(size_options.map { |o| o['presentation'] }).to include('S', 'M')

      small_option = size_options.find { |o| o['presentation'] == 'S' }
      expect(small_option['count']).to eq(1)
    end

    it 'returns all sort options' do
      get :index

      sort_ids = json_response['sort_options'].map { |s| s['id'] }
      expect(sort_ids).to include(
        'manual', 'best_selling', 'price asc', 'price desc',
        'available_on desc', 'available_on asc', 'name asc', 'name desc'
      )
    end

    it 'returns total product count' do
      get :index

      expect(json_response['total_count']).to eq(3)
    end

    context 'with taxon_id parameter' do
      it 'scopes filters to taxon' do
        get :index, params: { taxon_id: child_taxon1.prefixed_id }

        expect(json_response['total_count']).to eq(2) # Only products in child_taxon1
      end

      it 'returns child taxons as filter options' do
        get :index, params: { taxon_id: taxon.prefixed_id }

        taxon_filter = json_response['filters'].find { |f| f['type'] == 'taxon' }
        expect(taxon_filter).to be_present

        taxon_options = taxon_filter['options']
        expect(taxon_options.map { |t| t['name'] }).to include('Shirts', 'Pants')
      end

      it 'returns default_sort from taxon' do
        taxon.update!(sort_order: 'price asc')

        get :index, params: { taxon_id: taxon.prefixed_id }

        expect(json_response['default_sort']).to eq('price asc')
      end
    end

    context 'with ransack query params' do
      it 'applies ransack filters to scope' do
        get :index, params: { q: { name_cont: product1.name } }

        expect(json_response['total_count']).to eq(1)
      end
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
