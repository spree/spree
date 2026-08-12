require 'spec_helper'

# The Store API products controller delegating to the Meilisearch provider —
# the wiring that only holds when this gem is installed. Provider-agnostic
# controller behaviour is covered by spree_api's own products controller spec.
RSpec.describe Spree::Api::V3::Store::ProductsController, type: :controller do
  # The dummy app mounts only spree_core's routes, so drive the real controller
  # through an anonymous subclass rather than the named route.
  controller(Spree::Api::V3::Store::ProductsController) {}

  render_views

  include_context 'API v3 Store'

  let!(:product) { create(:product, status: 'active') }
  let!(:product2) { create(:product, status: 'active') }
  let!(:draft_product) { create(:product, status: 'draft') }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  after do
    I18n.locale = store.default_locale
  end

  describe 'GET #index' do
    let(:mock_client) { instance_double(::Meilisearch::Client) }
    let(:mock_index) { double('Meilisearch::Index') }

    before do
      allow(Spree).to receive(:search_provider).and_return('SpreeMeilisearch::SearchProvider')
      allow(::Meilisearch::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:index).and_return(mock_index)
    end

    after do
      allow(Spree).to receive(:search_provider).and_call_original
    end

    it 'searches via Meilisearch when q[search] is present' do
      allow(mock_index).to receive(:search).and_return({
        'hits' => [{ 'product_id' => product.prefixed_id }],
        'totalHits' => 1,
        'facetDistribution' => {}
      })

      get :index, params: { q: { search: 'shirt' } }

      expect(response).to have_http_status(:ok)
      expect(mock_index).to have_received(:search).with('shirt', hash_including(:page, :hitsPerPage))

      ids = json_response['data'].map { |p| p['id'] }
      expect(ids).to include(product.prefixed_id)
      expect(ids).not_to include(product2.prefixed_id)
    end

    it 'respects AR scope visibility (does not return draft products from Meilisearch)' do
      allow(mock_index).to receive(:search).and_return({
        'hits' => [{ 'product_id' => product.prefixed_id }, { 'product_id' => draft_product.prefixed_id }],
        'totalHits' => 2,
        'facetDistribution' => {}
      })

      get :index, params: { q: { search: 'test' } }

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].map { |p| p['id'] }
      expect(ids).to include(product.prefixed_id)
      expect(ids).not_to include(draft_product.prefixed_id)
    end

    it 'uses Meilisearch for browsing without search query' do
      allow(mock_index).to receive(:search).and_return({
        'hits' => [{ 'product_id' => product.prefixed_id }, { 'product_id' => product2.prefixed_id }],
        'totalHits' => 2,
        'facetDistribution' => {}
      })

      get :index

      expect(response).to have_http_status(:ok)
      expect(mock_index).to have_received(:search)
      expect(json_response['data'].size).to eq(2)
    end

    it 'filters by current locale in Meilisearch' do
      allow(mock_index).to receive(:search).and_return({
        'hits' => [{ 'product_id' => product.prefixed_id }],
        'totalHits' => 1,
        'facetDistribution' => {}
      })

      get :index

      expect(response).to have_http_status(:ok)
      expect(mock_index).to have_received(:search).with(anything, hash_including(
        filter: include("locale = '#{store.default_locale}'")
      ))
    end

    it 'filters by current currency in Meilisearch' do
      allow(mock_index).to receive(:search).and_return({
        'hits' => [{ 'product_id' => product.prefixed_id }],
        'totalHits' => 1,
        'facetDistribution' => {}
      })

      get :index

      expect(response).to have_http_status(:ok)
      expect(mock_index).to have_received(:search).with(anything, hash_including(
        filter: include("currency = '#{store.default_currency}'")
      ))
    end

    it 'filters by store_id in Meilisearch' do
      allow(mock_index).to receive(:search).and_return({
        'hits' => [{ 'product_id' => product.prefixed_id }],
        'totalHits' => 1,
        'facetDistribution' => {}
      })

      get :index

      expect(response).to have_http_status(:ok)
      expect(mock_index).to have_received(:search).with(anything, hash_including(
        filter: include("store_ids = '#{store.id}'")
      ))
    end

    it 'always filters by active status in Meilisearch' do
      allow(mock_index).to receive(:search).and_return({
        'hits' => [{ 'product_id' => product.prefixed_id }],
        'totalHits' => 1,
        'facetDistribution' => {}
      })

      get :index

      expect(response).to have_http_status(:ok)
      expect(mock_index).to have_received(:search).with(anything, hash_including(
        filter: include("status = 'active'")
      ))
    end

    it 'preserves Meilisearch sort order in the response' do
      allow(mock_index).to receive(:search).and_return({
        'hits' => [{ 'product_id' => product2.prefixed_id }, { 'product_id' => product.prefixed_id }],
        'totalHits' => 2,
        'facetDistribution' => {}
      })

      get :index, params: { sort: '-price' }

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].map { |p| p['id'] }
      expect(ids).to eq([product2.prefixed_id, product.prefixed_id])
    end
  end
end
