require 'spec_helper'

# The Store API filters endpoint delegating to the Meilisearch provider. Its
# cache key reads the provider's custom field schema, so the provider must
# expose it like the base provider does.
RSpec.describe Spree::Api::V3::Store::Products::FiltersController, type: :controller do
  controller(Spree::Api::V3::Store::Products::FiltersController) do
    # The dummy app mounts only spree_core's routes, so drive the real
    # controller through an anonymous subclass rather than the named route.
  end

  render_views

  include_context 'API v3 Store'

  let!(:product) { create(:product, status: 'active') }
  let(:mock_client) { instance_double(Meilisearch::Client) }
  let(:mock_index) { double('Meilisearch::Index') }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    allow(Spree).to receive(:search_provider).and_return('SpreeMeilisearch::SearchProvider')
    allow(Meilisearch::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:index).and_return(mock_index)
    allow(mock_index).to receive(:search).and_return({
      'hits' => [],
      'totalHits' => 1,
      'facetDistribution' => {},
      'facetStats' => {}
    })
  end

  after do
    allow(Spree).to receive(:search_provider).and_call_original
  end

  describe 'GET #index' do
    it 'returns facets from Meilisearch' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(mock_index).to have_received(:search)
      expect(json_response['total_count']).to eq(1)
    end
  end
end
