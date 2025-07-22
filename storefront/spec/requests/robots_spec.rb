require 'spec_helper'

describe 'Robots.txt', type: :request do
  let(:store) { @default_store }

  context 'when the store does not prefer to be indexed in search engines' do
    it 'returns the robots.txt file' do
      get '/robots.txt'

      expect(response).to have_http_status(:success)
      expect(response.body).to include('User-agent: *')
      expect(response.body).to include('Disallow: /')
    end
  end

  context 'when the store prefers to be indexed in search engines' do
    around do |example|
      preferred_index_in_search_engines = store.preferred_index_in_search_engines
      store.update(preferred_index_in_search_engines: true)
      example.run
      store.update(preferred_index_in_search_engines: preferred_index_in_search_engines)
    end

    it 'returns the robots.txt file' do
      get '/robots.txt'

      expect(response).to have_http_status(:success)
      expect(response.body).to include('User-agent: *')
      expect(response.body).not_to include(/^Disallow: \/$/)
      expect(response.body).to include("Sitemap: #{spree.sitemap_url(host: store.formatted_url_or_custom_domain, format: :xml, port: nil)}")
    end
  end
end
