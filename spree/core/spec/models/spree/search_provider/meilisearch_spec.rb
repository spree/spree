require 'spec_helper'
require 'meilisearch'

module Spree
  RSpec.describe SearchProvider::Meilisearch do
    let(:store) { @default_store }
    let(:provider) { described_class.new(store) }
    let(:mock_client) { instance_double(::Meilisearch::Client) }
    let(:mock_index) { double('MeiliSearch::Index') }

    let!(:product_1) { create(:product, name: 'Blue Shirt', stores: [store]) }
    let!(:product_2) { create(:product, name: 'Red Pants', stores: [store]) }

    before do
      allow(::Meilisearch::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:index).and_return(mock_index)
      allow(mock_index).to receive(:update_filterable_attributes)
      allow(mock_index).to receive(:update_sortable_attributes)
      allow(mock_index).to receive(:update_searchable_attributes)
    end

    describe '#search_and_filter' do
      let(:ms_response) do
        {
          'hits' => [
            { 'product_id' => product_1.prefixed_id },
            { 'product_id' => product_2.prefixed_id }
          ],
          'estimatedTotalHits' => 2,
          'facetDistribution' => {
            'in_stock' => { 'true' => 2 },
            'price' => { '19.99' => 1, '29.99' => 1 }
          }
        }
      end

      before do
        allow(mock_index).to receive(:search).and_return(ms_response)
      end

      it 'returns a SearchResult' do
        result = provider.search_and_filter(scope: store.products, query: 'shirt')
        expect(result).to be_a(SearchProvider::SearchResult)
      end

      it 'queries Meilisearch with the search term' do
        expect(mock_index).to receive(:search).with('shirt', hash_including(:limit, :offset))
        provider.search_and_filter(scope: store.products, query: 'shirt')
      end

      it 'returns products from the AR scope matching Meilisearch IDs' do
        result = provider.search_and_filter(scope: store.products, query: 'shirt')
        expect(result.products).to include(product_1, product_2)
      end

      it 'returns total count from Meilisearch' do
        result = provider.search_and_filter(scope: store.products, query: 'shirt')
        expect(result.total_count).to eq(2)
      end

      it 'does not request facets from Meilisearch' do
        expect(mock_index).to receive(:search).with(anything, satisfy { |params| !params.key?(:facets) })
        provider.search_and_filter(scope: store.products, query: 'shirt')
      end

      context 'with no results' do
        let(:ms_response) { { 'hits' => [], 'estimatedTotalHits' => 0, 'facetDistribution' => {} } }

        it 'returns empty relation' do
          result = provider.search_and_filter(scope: store.products, query: 'nonexistent')
          expect(result.products).to be_empty
          expect(result.total_count).to eq(0)
        end
      end

      context 'with price filter' do
        it 'passes price filter to Meilisearch' do
          expect(mock_index).to receive(:search).with(anything, hash_including(
            filter: include('price >= 10.0')
          )).and_return(ms_response)

          provider.search_and_filter(scope: store.products, filters: { 'price_gte' => '10' })
        end
      end

      context 'with in_stock filter' do
        it 'passes stock filter to Meilisearch' do
          expect(mock_index).to receive(:search).with(anything, hash_including(
            filter: include('in_stock = true')
          )).and_return(ms_response)

          provider.search_and_filter(scope: store.products, filters: { 'in_stock' => '1' })
        end
      end

      context 'with sort' do
        it 'passes price sort to Meilisearch' do
          expect(mock_index).to receive(:search).with(anything, hash_including(
            sort: ['price:asc']
          )).and_return(ms_response)

          provider.search_and_filter(scope: store.products, sort: 'price')
        end

        it 'passes descending price sort' do
          expect(mock_index).to receive(:search).with(anything, hash_including(
            sort: ['price:desc']
          )).and_return(ms_response)

          provider.search_and_filter(scope: store.products, sort: '-price')
        end
      end

      context 'with pagination' do
        it 'passes offset and limit' do
          expect(mock_index).to receive(:search).with(anything, hash_including(
            offset: 25, limit: 25
          )).and_return(ms_response)

          provider.search_and_filter(scope: store.products, page: 2, limit: 25)
        end
      end

      context 'with sort order preservation' do
        it 'returns products in the order Meilisearch returned them' do
          reversed_response = {
            'hits' => [
              { 'product_id' => product_2.prefixed_id },
              { 'product_id' => product_1.prefixed_id }
            ],
            'estimatedTotalHits' => 2,
            'facetDistribution' => {}
          }
          allow(mock_index).to receive(:search).and_return(reversed_response)

          result = provider.search_and_filter(scope: store.products, query: 'shirt')
          expect(result.products).to eq([product_2, product_1])
        end
      end

      context 'with visibility scope' do
        it 'intersects Meilisearch results with AR scope' do
          restricted_scope = store.products.where(id: product_1.id)
          result = provider.search_and_filter(scope: restricted_scope, query: 'shirt')
          expect(result.products).to include(product_1)
          expect(result.products).not_to include(product_2)
        end
      end
    end

    describe '#filters' do
      let(:ms_response) do
        {
          'hits' => [],
          'estimatedTotalHits' => 2,
          'processingTimeMs' => 1,
          'facetDistribution' => {
            'in_stock' => { 'true' => 2 },
            'price' => { '19.99' => 1, '29.99' => 1 }
          }
        }
      end

      before do
        allow(mock_index).to receive(:search).and_return(ms_response)
      end

      it 'returns a FiltersResult' do
        result = provider.filters(scope: store.products, query: 'shirt')
        expect(result).to be_a(SearchProvider::FiltersResult)
      end

      it 'returns facets from Meilisearch' do
        result = provider.filters(scope: store.products, query: 'shirt')
        expect(result.filters).to be_an(Array)

        price_filter = result.filters.find { |f| f[:type] == 'price_range' }
        expect(price_filter).to be_present
        expect(price_filter[:min]).to eq(19.99)
        expect(price_filter[:max]).to eq(29.99)
      end

      it 'returns sort options as objects' do
        result = provider.filters(scope: store.products, query: 'shirt')
        ids = result.sort_options.map { |o| o[:id] }
        expect(ids).to include('price', '-price')
      end

      it 'returns total count' do
        result = provider.filters(scope: store.products, query: 'shirt')
        expect(result.total_count).to eq(2)
      end

      it 'requests facets from Meilisearch' do
        expect(mock_index).to receive(:search).with(anything, hash_including(:facets))
        provider.filters(scope: store.products, query: 'shirt')
      end

      context 'with option type facets' do
        let(:color_type) { create(:option_type, :color_swatch, filterable: true) }
        let(:red_value) { create(:option_value, option_type: color_type, name: 'red', presentation: 'Red', color_code: '#FF0000') }
        let(:blue_value) { create(:option_value, option_type: color_type, name: 'blue', presentation: 'Blue', color_code: '#0000FF') }

        let(:ms_response) do
          {
            'hits' => [],
            'estimatedTotalHits' => 1,
            'processingTimeMs' => 1,
            'facetDistribution' => {
              'option_value_ids' => {
                red_value.prefixed_id => 3,
                blue_value.prefixed_id => 1
              }
            }
          }
        end

        it 'includes kind on option type filters' do
          result = provider.filters(scope: store.products, query: '')
          color_filter = result.filters.find { |f| f[:name] == 'color' }

          expect(color_filter).to be_present
          expect(color_filter[:kind]).to eq('color_swatch')
        end

        it 'includes color_code on option values' do
          result = provider.filters(scope: store.products, query: '')
          color_filter = result.filters.find { |f| f[:name] == 'color' }
          red_option = color_filter[:options].find { |o| o[:name] == 'red' }

          expect(red_option[:color_code]).to eq('#FF0000')
        end

        it 'includes image_url as nil when no image attached' do
          result = provider.filters(scope: store.products, query: '')
          color_filter = result.filters.find { |f| f[:name] == 'color' }
          red_option = color_filter[:options].find { |o| o[:name] == 'red' }

          expect(red_option[:image_url]).to be_nil
        end
      end

      context 'when Meilisearch API fails' do
        before do
          error = ::Meilisearch::ApiError.new(500, 'internal error', 'internal')
          allow(mock_index).to receive(:search).and_raise(error)
        end

        it 'returns empty FiltersResult' do
          result = provider.filters(scope: store.products, query: 'shirt')
          expect(result.filters).to eq([])
          expect(result.total_count).to eq(0)
        end
      end
    end

    describe '#index' do
      it 'adds documents to Meilisearch index with id as primary key' do
        expect(mock_index).to receive(:add_documents).with(
          array_including(hash_including(product_id: product_1.prefixed_id, name: 'Blue Shirt')),
          'id'
        )
        provider.index(product_1)
      end

      it 'uses ProductPresenter to serialize' do
        docs = [{ id: 'prod_abc_en_USD', product_id: 'prod_abc' }]
        presenter = instance_double(SearchProvider::ProductPresenter, call: docs)
        allow(SearchProvider::ProductPresenter).to receive(:new).with(product_1, store).and_return(presenter)
        expect(mock_index).to receive(:add_documents).with(docs, 'id')
        provider.index(product_1)
      end
    end

    describe '#remove' do
      it 'deletes all locale/currency variants by product_id filter' do
        expect(mock_index).to receive(:delete_documents).with(filter: "product_id = '#{product_1.prefixed_id}'")
        provider.remove(product_1)
      end
    end

    describe '#remove_by_id' do
      it 'deletes all documents by product_id filter' do
        expect(mock_index).to receive(:delete_documents).with(filter: "product_id = 'prod_abc'")
        provider.remove_by_id('prod_abc')
      end

      it 'ignores 404 errors' do
        error = ::Meilisearch::ApiError.new(404, 'not found', 'document_not_found')
        allow(mock_index).to receive(:delete_documents).and_raise(error)
        expect { provider.remove_by_id('prod_abc') }.not_to raise_error
      end
    end

    describe '#reindex' do
      it 'configures index settings' do
        expect(mock_index).to receive(:update_filterable_attributes)
        expect(mock_index).to receive(:update_sortable_attributes)
        expect(mock_index).to receive(:update_searchable_attributes)
        allow(mock_index).to receive(:add_documents)

        provider.reindex(store.products)
      end

      it 'indexes all products in batches' do
        expect(mock_index).to receive(:add_documents).at_least(:once)
        provider.reindex(store.products)
      end
    end
  end
end
