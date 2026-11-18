require 'spec_helper'

module Spree
  RSpec.describe SearchProvider::Postgres, if: ActiveRecord::Base.connection.adapter_name == 'PostgreSQL' do
    let(:store) { @default_store }
    let(:provider) { described_class.new(store) }
    let(:scope) { store.products }

    let!(:shirt) { create(:product, name: 'Blue Shirt', description: '<blockquote>Soft cotton</blockquote>') }
    let!(:pants) { create(:product, name: 'Red Pants', description: '<p>Goes well with a blue jacket</p>') }
    let!(:jacket) { create(:product, name: 'Blue Jacket', description: '<p>Waterproof shell</p>') }

    def search(query, **options)
      provider.search_and_filter(scope: scope, query: query, **options)
    end

    it 'is the default provider on PostgreSQL' do
      expect(Spree.search_provider).to eq('Spree::SearchProvider::Postgres')
    end

    describe '#search_and_filter' do
      it 'matches words in any order' do
        expect(search('shirt blue').products).to contain_exactly(shirt)
      end

      it 'matches other forms of a word' do
        expect(search('shirts').products).to contain_exactly(shirt)
      end

      it 'matches the last word as a prefix' do
        expect(search('blue jac').products.first).to eq(jacket)
      end

      it 'searches descriptions and ranks a name match above a description match' do
        expect(search('waterproof').products).to contain_exactly(jacket)
        expect(search('jacket').products.to_a).to eq([jacket, pants])
      end

      it 'does not match markup in a description' do
        expect(search('cotton').products).to contain_exactly(shirt)
        expect(search('blockquote').products).to be_empty
      end

      it 'still matches part of a name and a SKU' do
        shirt.default_variant.update!(sku: 'SKU-BLUE-001')

        expect(search('acke').products).to contain_exactly(jacket)
        expect(search('sku-blue').products).to contain_exactly(shirt)
      end

      it 'matches a decimal number among other words' do
        kettle = create(:product, name: 'Glass Kettle 1.7L')

        expect(search('kettle 1.7l').products).to contain_exactly(kettle)
        expect(search('1.7 glass').products).to contain_exactly(kettle)
      end

      it 'ranks a product matching every word above one found only by its SKU' do
        jacket.default_variant.update!(sku: 'blue jacket waterproof')
        full_match = create(:product, name: 'Parka', description: 'A blue and fully waterproof winter jacket')
        jacket.update!(description: 'Shell')

        expect(search('blue jacket waterproof').products.to_a).to eq([full_match, jacket])
      end

      it 'ranks when the sort is manual with nothing to order within' do
        expect(search('jacket', sort: 'manual').products.to_a).to eq([jacket, pants])
      end

      it 'falls back to the plain match for a very long query' do
        expect(search("shirt #{'blue ' * 50}").products).to be_empty
        expect(search("Blue Shirt#{' ' * 200}").products).to contain_exactly(shirt)
      end

      it 'returns the total count and pages' do
        result = search('blue', limit: 1)

        expect(result.total_count).to eq(3)
        expect(result.products.length).to eq(1)
      end

      it 'keeps an explicit sort' do
        expect(search('blue', sort: '-name').products.map(&:name)).to eq(['Red Pants', 'Blue Shirt', 'Blue Jacket'])
      end

      it 'combines the query with filters' do
        expect(search('blue', filters: { 'name_cont' => 'Shirt' }).products).to contain_exactly(shirt)
      end

      it 'returns nothing for a query nothing matches' do
        expect(search('umbrella').total_count).to eq(0)
      end

      it 'treats search syntax in the query as plain words' do
        expect(search("blue & !shirt | ':*").products).to contain_exactly(shirt)
      end

      it 'returns everything without a query' do
        expect(search(nil).total_count).to eq(3)
      end

      context 'with typo tolerance' do
        before { skip 'pg_trgm is not enabled' unless described_class.typo_tolerance? }

        it 'falls back to the closest names when nothing matches as typed' do
          expect(search('jackt').products).to contain_exactly(jacket)
          expect(search('blue shrt').products.first).to eq(shirt)
        end

        it 'does not offer names that only share a few letters' do
          expect(search('shaver').products).to be_empty
        end

        it 'adds nothing to a search that found a match' do
          create(:product, name: 'Jackal Mask')

          expect(search('jacket').products).to contain_exactly(jacket, pants)
        end

        it 'does not fall back when a filter is what left the query without a match' do
          create(:product, name: 'Jackt')

          expect(search('jacket', filters: { 'name_cont' => 'Jackt' }).products).to be_empty
        end

        it 'still falls back when the only match as typed is hidden from the shopper' do
          create(:product, name: 'Jackt Prototype', status: 'draft')

          expect(provider.search_and_filter(scope: scope.where(status: 'active'), query: 'jackt').products).to contain_exactly(jacket)
        end
      end

      context 'without typo tolerance' do
        before { allow(described_class).to receive(:typo_tolerance?).and_return(false) }

        it 'does not match a misspelled name' do
          expect(search('jackt').products).to be_empty
        end
      end

      context 'in a translated locale' do
        before { create(:product_translation, translated_model: pants, locale: 'de', name: 'Rote Hosen', description: 'Bequeme Baumwolle') }

        it 'matches the translation with that language, and still the base text' do
          I18n.with_locale(:de) do
            expect(search('hose').products).to contain_exactly(pants)
            expect(search('baumwolle').products).to contain_exactly(pants)
            expect(search('shirt').products).to contain_exactly(shirt)
            expect(search('rote hosn').products.first).to eq(pants) if described_class.typo_tolerance?
          end
        end
      end
    end

    describe '#filters' do
      it 'counts the products the query matches' do
        expect(provider.filters(scope: scope, query: 'shirts').total_count).to eq(1)
      end
    end

    it 'reads the search index' do
      plan = Spree::Product.transaction do
        # Leaves a bitmap scan of the search index as the only cheap way to match.
        Spree::Product.connection.execute('SET LOCAL enable_seqscan = off; SET LOCAL enable_indexscan = off')
        Spree::Product.connection.select_values("EXPLAIN #{search('cotton').products.to_sql}").join
      end

      expect(plan).to include('index_spree_products_on_search_vector_english')
    end

    describe '.missing_indexes' do
      it 'is empty on a migrated database' do
        expect(described_class.missing_indexes).to be_empty
      end
    end
  end
end
