require 'spec_helper'

describe 'Sitemap', type: :request do
  let(:store) { @default_store }

  context 'search engines disabled' do
    around do |example|
      preferred_index_in_search_engines = store.preferred_index_in_search_engines
      store.update(preferred_index_in_search_engines: false)
      example.run
      store.update(preferred_index_in_search_engines: preferred_index_in_search_engines)
    end

    context 'when requesting gzipped sitemap' do
      it 'returns 404' do
        get '/sitemap.xml.gz'
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when requesting xml sitemap' do
      it 'returns 404' do
        get '/sitemap.xml'
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  context 'search engines enabled' do
    around do |example|
      preferred_index_in_search_engines = store.preferred_index_in_search_engines
      store.update(preferred_index_in_search_engines: true)
      example.run
      store.update(preferred_index_in_search_engines: preferred_index_in_search_engines)
    end

    it 'returns sitemap' do
      get '/sitemap.xml'
      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq('application/xml; charset=utf-8')
      expect(response.body).to start_with('<?xml version="1.0" encoding="UTF-8"?>')
      expect(response.body).to include('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
    end

    it 'also works for xml.gz format' do
      get '/sitemap.xml.gz'
      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq('application/x-gzip')
      expect(response.headers['Content-Disposition']).to include('inline')
      expect(response.headers['Content-Disposition']).to include('filename="sitemap.xml.gz"')

      # Decompress and check content
      gz = Zlib::GzipReader.new(StringIO.new(response.body))
      xml_content = gz.read
      expect(xml_content).to start_with('<?xml version="1.0" encoding="UTF-8"?>')
      expect(xml_content).to include('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
    end

    context 'with content' do
      let!(:products) { create_list(:product, 5, stores: [store], status: :active) }
      let!(:taxonomy) { create(:taxonomy, store: store) }
      let!(:taxons) { create_list(:taxon, 5, taxonomy: taxonomy) }

      it 'containts links to products and taxons' do
        get '/sitemap.xml'
        expect(response).to have_http_status(:success)

        xml = Nokogiri::XML(response.body)
        urls = xml.xpath('//xmlns:url/xmlns:loc').map(&:text)

        products.each do |product|
          expect(urls).to include(spree.product_url(product, host: store.url, port: Capybara.server_port))
        end

        taxonomy.taxons.each do |taxon|
          expect(urls).to include(spree.nested_taxons_url(taxon, host: store.url, port: Capybara.server_port))
        end
      end
    end
  end
end
