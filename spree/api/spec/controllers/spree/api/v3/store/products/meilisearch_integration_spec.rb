require 'spec_helper'
require 'meilisearch'

# Integration tests that run against a real Meilisearch instance.
# Requires MEILISEARCH_URL to be set (e.g. http://localhost:7700).
# In CI, Meilisearch runs as a service container.
# Locally: `brew install meilisearch && meilisearch`
#
# Run with: bundle exec rspec spec/controllers/spree/api/v3/store/products/meilisearch_integration_spec.rb
RSpec.describe 'Meilisearch Integration', type: :controller, if: ENV['MEILISEARCH_URL'].present? do
  controller(Spree::Api::V3::Store::ProductsController) {}

  include_context 'API v3 Store'

  before(:all) { WebMock.allow_net_connect!(allow_localhost: true) }
  after(:all) { WebMock.disable_net_connect! }

  let(:provider) { Spree::SearchProvider::Meilisearch.new(store) }
  let(:index_name) { "#{store.code}_products" }

  # Categories
  let(:taxonomy) { create(:taxonomy, store: store) }
  let(:clothing_category) { create(:taxon, name: 'Clothing', taxonomy: taxonomy) }
  let(:shoes_category) { create(:taxon, name: 'Shoes', taxonomy: taxonomy) }

  # Option types
  let(:color_option) { create(:option_type, name: 'color', presentation: 'Color', filterable: true) }
  let(:size_option) { create(:option_type, name: 'size', presentation: 'Size', filterable: true) }
  let(:red) { create(:option_value, option_type: color_option, name: 'red', presentation: 'Red') }
  let(:blue) { create(:option_value, option_type: color_option, name: 'blue', presentation: 'Blue') }
  let(:small) { create(:option_value, option_type: size_option, name: 'small', presentation: 'S') }
  let(:large) { create(:option_value, option_type: size_option, name: 'large', presentation: 'L') }

  # create(:product) seeds an option-less placeholder default variant priced by
  # the factory. Once real option variants exist that placeholder is meaningless
  # (import/admin flows delete it), so drop it and re-point the default — otherwise
  # the product's price resolves to the placeholder's factory price, not the variant's.
  def make_default_variant(product, variant)
    product.update!(default_variant_id: variant.id)
    product.variants.where.missing(:option_value_variants).destroy_all
    product.reload
  end

  # Products with different attributes
  let!(:cheap_red_shirt) do
    p = create(:product, name: 'Red Cotton Shirt', status: 'active', store: store, taxons: [clothing_category])
    p.option_types << color_option
    p.option_types << size_option
    v = create(:variant, product: p, option_values: [red, small])
    v.prices.find_or_create_by!(currency: 'USD').update!(amount: 19.99)
    make_default_variant(p, v)
    p
  end

  let!(:expensive_blue_shirt) do
    p = create(:product, name: 'Blue Silk Shirt', status: 'active', store: store, taxons: [clothing_category])
    p.option_types << color_option
    v = create(:variant, product: p, option_values: [blue, large])
    v.prices.find_or_create_by!(currency: 'USD').update!(amount: 89.99)
    make_default_variant(p, v)
    p
  end

  let!(:blue_shoes) do
    p = create(:product, name: 'Blue Running Shoes', status: 'active', store: store, taxons: [shoes_category])
    p.option_types << color_option
    p.option_types << size_option
    v = create(:variant, product: p, option_values: [blue, small])
    v.prices.find_or_create_by!(currency: 'USD').update!(amount: 129.99)
    make_default_variant(p, v)
    p
  end

  let!(:draft_product) { create(:product, name: 'Draft Hat', status: 'draft') }

  let!(:future_product) do
    create(:product, name: 'Future Coat', status: 'active', store: store, available_on: 2.weeks.from_now, price: 99.99)
  end

  let!(:discontinued_product) do
    create(:product, name: 'Old Jacket', status: 'active', store: store, discontinue_on: 2.days.ago, price: 49.99)
  end

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    allow(Spree).to receive(:search_provider).and_return('Spree::SearchProvider::Meilisearch')

    provider.reindex(store.products)
    wait_for_meilisearch_indexing!
  end

  after do
    client = ::Meilisearch::Client.new(ENV['MEILISEARCH_URL'])
    client.delete_index(index_name) rescue nil
    allow(Spree).to receive(:search_provider).and_call_original
  end

  describe 'text search' do
    it 'finds products by name' do
      get :index, params: { q: { search: 'shirt' } }

      expect(response).to have_http_status(:ok)
      names = json_response['data'].map { |p| p['name'] }
      expect(names).to include('Red Cotton Shirt', 'Blue Silk Shirt')
      expect(names).not_to include('Blue Running Shoes')
    end

    it 'finds products with typo tolerance' do
      get :index, params: { q: { search: 'shrit' } }

      expect(response).to have_http_status(:ok)
      names = json_response['data'].map { |p| p['name'] }
      expect(names).to include('Red Cotton Shirt')
    end

    it 'finds products by partial match' do
      get :index, params: { q: { search: 'blue' } }

      expect(response).to have_http_status(:ok)
      names = json_response['data'].map { |p| p['name'] }
      expect(names).to include('Blue Silk Shirt', 'Blue Running Shoes')
      expect(names).not_to include('Red Cotton Shirt')
    end
  end

  describe 'filtering by price' do
    it 'filters by minimum price' do
      get :index, params: { q: { price_gte: '50' } }

      expect(response).to have_http_status(:ok)
      names = json_response['data'].map { |p| p['name'] }
      expect(names).to include('Blue Silk Shirt', 'Blue Running Shoes')
      expect(names).not_to include('Red Cotton Shirt')
    end

    it 'filters by maximum price' do
      get :index, params: { q: { price_lte: '50' } }

      expect(response).to have_http_status(:ok)
      names = json_response['data'].map { |p| p['name'] }
      expect(names).to include('Red Cotton Shirt')
      expect(names).not_to include('Blue Silk Shirt', 'Blue Running Shoes')
    end

    it 'filters by price range' do
      get :index, params: { q: { price_gte: '50', price_lte: '100' } }

      expect(response).to have_http_status(:ok)
      names = json_response['data'].map { |p| p['name'] }
      expect(names).to include('Blue Silk Shirt')
      expect(names).not_to include('Red Cotton Shirt', 'Blue Running Shoes')
    end
  end

  describe 'filtering by category' do
    it 'filters by category ID' do
      get :index, params: { q: { in_category: clothing_category.prefixed_id } }

      expect(response).to have_http_status(:ok)
      names = json_response['data'].map { |p| p['name'] }
      expect(names).to include('Red Cotton Shirt', 'Blue Silk Shirt')
      expect(names).not_to include('Blue Running Shoes')
    end
  end

  describe 'filtering by option values' do
    it 'filters by color option value' do
      get :index, params: { q: { with_option_value_ids: [blue.prefixed_id] } }

      expect(response).to have_http_status(:ok)
      names = json_response['data'].map { |p| p['name'] }
      expect(names).to include('Blue Silk Shirt', 'Blue Running Shoes')
      expect(names).not_to include('Red Cotton Shirt')
    end

    it 'filters by size option value' do
      get :index, params: { q: { with_option_value_ids: [small.prefixed_id] } }

      expect(response).to have_http_status(:ok)
      names = json_response['data'].map { |p| p['name'] }
      expect(names).to include('Red Cotton Shirt', 'Blue Running Shoes')
      expect(names).not_to include('Blue Silk Shirt')
    end
  end

  describe 'combined search + filters' do
    it 'searches text and filters by price' do
      get :index, params: { q: { search: 'blue', price_lte: '100' } }

      expect(response).to have_http_status(:ok)
      names = json_response['data'].map { |p| p['name'] }
      expect(names).to include('Blue Silk Shirt')
      expect(names).not_to include('Blue Running Shoes', 'Red Cotton Shirt')
    end

    it 'searches text and filters by category' do
      get :index, params: { q: { search: 'blue', in_category: shoes_category.prefixed_id } }

      expect(response).to have_http_status(:ok)
      names = json_response['data'].map { |p| p['name'] }
      expect(names).to include('Blue Running Shoes')
      expect(names).not_to include('Blue Silk Shirt', 'Red Cotton Shirt')
    end

    it 'searches text and filters by option value' do
      get :index, params: { q: { search: 'shirt', with_option_value_ids: [red.prefixed_id] } }

      expect(response).to have_http_status(:ok)
      names = json_response['data'].map { |p| p['name'] }
      expect(names).to include('Red Cotton Shirt')
      expect(names).not_to include('Blue Silk Shirt')
    end
  end

  describe 'visibility' do
    it 'excludes draft products' do
      get :index

      expect(response).to have_http_status(:ok)
      names = json_response['data'].map { |p| p['name'] }
      expect(names).not_to include('Draft Hat')
    end

    it 'excludes products with a future available_on from both data and count' do
      get :index

      expect(response).to have_http_status(:ok)
      names = json_response['data'].map { |p| p['name'] }
      expect(names).not_to include('Future Coat')
      expect(json_response['meta']['count']).to eq(names.size)
    end

    it 'excludes products discontinued in the past from both data and count' do
      get :index

      expect(response).to have_http_status(:ok)
      names = json_response['data'].map { |p| p['name'] }
      expect(names).not_to include('Old Jacket')
      expect(json_response['meta']['count']).to eq(names.size)
    end
  end

  describe 'browsing without search query' do
    it 'returns all active, available, non-discontinued products' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(3)
    end
  end

  describe 'pagination' do
    it 'paginates results' do
      get :index, params: { limit: 2, page: 1 }

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(2)
      expect(json_response['meta']['count']).to be >= 3
    end
  end

  private

  def wait_for_meilisearch_indexing!
    client = ::Meilisearch::Client.new(ENV['MEILISEARCH_URL'])

    # Wait for all tasks to complete (settings + document indexing)
    100.times do
      tasks = client.tasks(index_uids: [index_name], statuses: ['enqueued', 'processing'])
      break if tasks['results'].empty?

      sleep 0.1
    end

    # Extra wait for filterable attribute indexing to apply
    sleep 0.5
  end
end
