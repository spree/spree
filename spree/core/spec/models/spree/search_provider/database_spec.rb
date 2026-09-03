require 'spec_helper'

module Spree
  RSpec.describe SearchProvider::Database do
    let(:store) { @default_store }
    let(:provider) { described_class.new(store) }

    let!(:product_1) { create(:product, name: 'Blue Shirt') }
    let!(:product_2) { create(:product, name: 'Red Pants') }
    let!(:product_3) { create(:product, name: 'Blue Jacket') }

    describe '#search_and_filter' do
      let(:scope) { store.products }

      context 'with text search' do
        subject(:result) { provider.search_and_filter(scope: scope, query: 'blue') }

        it 'returns matching products' do
          expect(result.products).to include(product_1, product_3)
          expect(result.products).not_to include(product_2)
        end

        it 'returns a SearchResult' do
          expect(result).to be_a(SearchProvider::SearchResult)
        end

        it 'returns total count' do
          expect(result.total_count).to eq(2)
        end

        it 'does not include filter facets' do
          expect(result).not_to respond_to(:filters)
        end
      end

      context 'without search query' do
        subject(:result) { provider.search_and_filter(scope: scope) }

        it 'returns all products' do
          expect(result.products).to include(product_1, product_2, product_3)
        end

        it 'returns correct total count' do
          expect(result.total_count).to eq(3)
        end
      end

      context 'with blank query' do
        subject(:result) { provider.search_and_filter(scope: scope, query: '') }

        it 'returns all products' do
          expect(result.total_count).to eq(3)
        end
      end

      context 'with pagination' do
        subject(:result) { provider.search_and_filter(scope: scope, page: 1, limit: 2) }

        it 'limits results' do
          expect(result.products.length).to eq(2)
        end

        it 'returns full total count' do
          expect(result.total_count).to eq(3)
        end
      end

      context 'with page 2' do
        subject(:result) { provider.search_and_filter(scope: scope, page: 2, limit: 2) }

        it 'offsets results' do
          expect(result.products.length).to eq(1)
        end
      end

      context 'with sorting' do
        subject(:result) { provider.search_and_filter(scope: scope, sort: 'name') }

        it 'sorts by name ascending' do
          names = result.products.map(&:name)
          expect(names).to eq(names.sort)
        end
      end

      context 'with descending sort' do
        subject(:result) { provider.search_and_filter(scope: scope, sort: '-name') }

        it 'sorts by name descending' do
          names = result.products.map(&:name)
          expect(names).to eq(names.sort.reverse)
        end
      end

      context 'with custom price sort' do
        subject(:result) { provider.search_and_filter(scope: scope, sort: 'price') }

        it 'returns all products' do
          expect(result.total_count).to eq(3)
        end
      end

      context 'with ransack filters' do
        subject(:result) { provider.search_and_filter(scope: scope, filters: { 'name_cont' => 'Shirt' }) }

        it 'filters by ransack params' do
          expect(result.products).to include(product_1)
          expect(result.products).not_to include(product_2, product_3)
        end
      end

      context 'with search and filters combined' do
        subject(:result) { provider.search_and_filter(scope: scope, query: 'blue', filters: { 'name_cont' => 'Shirt' }) }

        it 'applies both search and filters' do
          expect(result.products).to include(product_1)
          expect(result.products).not_to include(product_2, product_3)
        end
      end

      context 'with in_category filter' do
        let(:parent_category) { create(:category, name: 'Clothing') }
        let(:child_category) { create(:category, parent: parent_category, name: 'Shirts') }

        before do
          product_1.categories << child_category
          product_2.categories << parent_category
        end

        it 'returns products directly in the category' do
          result = provider.search_and_filter(scope: scope, filters: { 'in_category' => child_category.prefixed_id })
          expect(result.products).to include(product_1)
          expect(result.products).not_to include(product_2, product_3)
        end

        it 'returns products in descendant categories when filtering by parent' do
          result = provider.search_and_filter(scope: scope, filters: { 'in_category' => parent_category.prefixed_id })
          expect(result.products).to include(product_1, product_2)
          expect(result.products).not_to include(product_3)
        end

        it 'returns no products for an invalid category ID' do
          result = provider.search_and_filter(scope: scope, filters: { 'in_category' => 'ctg_nonexistent' })
          expect(result.products).to be_empty
          expect(result.total_count).to eq(0)
        end
      end

      context 'with in_categories filter (multiple, OR logic)' do
        let(:shirts_taxon) { create(:category, name: 'Shirts') }
        let(:pants_taxon) { create(:category, name: 'Pants') }

        before do
          product_1.categories << shirts_taxon
          product_2.categories << pants_taxon
        end

        it 'returns products in any of the given categories' do
          result = provider.search_and_filter(scope: scope, filters: { 'in_categories' => [shirts_taxon.prefixed_id, pants_taxon.prefixed_id] })
          expect(result.products).to include(product_1, product_2)
          expect(result.products).not_to include(product_3)
        end
      end

      context 'with_option_value_ids disjunctive filtering' do
        let(:color) { create(:option_type, name: 'color', label: 'Color', filterable: true) }
        let(:size) { create(:option_type, name: 'size', label: 'Size', filterable: true) }
        let(:blue) { create(:option_value, option_type: color, name: 'blue', label: 'Blue') }
        let(:red) { create(:option_value, option_type: color, name: 'red', label: 'Red') }
        let(:small) { create(:option_value, option_type: size, name: 's', label: 'S') }
        let(:large) { create(:option_value, option_type: size, name: 'l', label: 'L') }

        before do
          create(:variant, product: product_1, option_values: [blue, small])  # product_1: Blue + S
          create(:variant, product: product_2, option_values: [red, small])   # product_2: Red + S
          create(:variant, product: product_3, option_values: [blue, large])  # product_3: Blue + L
        end

        it 'ORs within same option type: Blue OR Red returns all 3 products' do
          result = provider.search_and_filter(scope: scope, filters: { 'with_option_value_ids' => [blue.prefixed_id, red.prefixed_id] })
          expect(result.products).to include(product_1, product_2, product_3)
        end

        it 'ANDs across option types: Blue AND S returns only products with both' do
          result = provider.search_and_filter(scope: scope, filters: { 'with_option_value_ids' => [blue.prefixed_id, small.prefixed_id] })
          expect(result.products).to include(product_1)
          expect(result.products).not_to include(product_2, product_3)
        end

        it 'ANDs across option types: (Blue OR Red) AND S' do
          result = provider.search_and_filter(scope: scope, filters: { 'with_option_value_ids' => [blue.prefixed_id, red.prefixed_id, small.prefixed_id] })
          expect(result.products).to include(product_1, product_2)
          expect(result.products).not_to include(product_3)
        end
      end

      context "with 'manual' sort by category" do
        let(:parent_category) { create(:category, name: 'Clothing') }
        let(:child_category) { create(:category, parent: parent_category, name: 'Shirts') }

        before do
          # Positions deliberately differ from id/creation order so the assertion
          # proves position ordering (not incidental default order). Positions span
          # the parent AND its descendant — manual sort collapses the subtree by MIN.
          #
          # Built directly rather than through :product_category: the factory sets
          # a position, which makes acts_as_list renumber siblings on each insert
          # and overwrite the explicit values below.
          Spree::ProductCategory.create!(category: parent_category, product: product_2).update_column(:position, 1)
          Spree::ProductCategory.create!(category: child_category,  product: product_1).update_column(:position, 2)
          Spree::ProductCategory.create!(category: parent_category, product: product_3).update_column(:position, 3)
        end

        it 'orders products by their manual position within the category and its descendants' do
          result = provider.search_and_filter(scope: scope, filters: { 'in_category' => parent_category.prefixed_id }, sort: 'manual')
          expect(result.products.to_a).to eq([product_2, product_1, product_3])
        end
      end

      context "with 'manual' sort by collection" do
        let(:collection) { create(:collection, store: store) }

        before do
          Spree::ProductCollection.create!(collection: collection, product: product_3).update_column(:position, 1)
          Spree::ProductCollection.create!(collection: collection, product: product_1).update_column(:position, 2)
          Spree::ProductCollection.create!(collection: collection, product: product_2).update_column(:position, 3)
        end

        it 'orders products by their manual position within the collection' do
          result = provider.search_and_filter(scope: scope, filters: { 'in_collection' => collection.prefixed_id }, sort: 'manual')
          expect(result.products.to_a).to eq([product_3, product_1, product_2])
        end
      end

      context 'with no sort param on a category page' do
        let(:category) { create(:category, name: 'Clothing') }

        before do
          Spree::ProductCategory.create!(category: category, product: product_2).update_column(:position, 1)
          Spree::ProductCategory.create!(category: category, product: product_1).update_column(:position, 2)
        end

        it 'defaults to the merchant manual (position) order' do
          result = provider.search_and_filter(scope: scope, filters: { 'in_category' => category.prefixed_id })
          expect(result.products.to_a).to eq([product_2, product_1])
        end
      end

      context "with 'manual' sort and no category/collection filter" do
        subject(:result) { provider.search_and_filter(scope: scope, sort: 'manual') }

        it 'falls back to the default order without raising' do
          expect { result.products.to_a }.not_to raise_error
          expect(result.products).to include(product_1, product_2, product_3)
          expect(result.total_count).to eq(3)
        end
      end

      context 'with searchable custom_fields' do
        let!(:definition) do
          create(:custom_field_definition, :short_text_field, :searchable,
                 namespace: 'custom', key: 'label')
        end

        before do
          product_2.set_custom_field(definition, 'wool-blend')
        end

        it 'finds products by searchable custom_field value' do
          result = provider.search_and_filter(scope: scope, query: 'wool')
          expect(result.products).to include(product_2)
          expect(result.products).not_to include(product_1, product_3)
        end
      end

      context 'with sortable custom_fields' do
        let!(:definition) do
          create(:custom_field_definition, :short_text_field, :sortable,
                 namespace: 'custom', key: 'label')
        end

        before do
          product_1.set_custom_field(definition, 'charlie')
          product_2.set_custom_field(definition, 'alpha')
          product_3.set_custom_field(definition, 'bravo')
        end

        it 'sorts ascending by cf_* attribute' do
          result = provider.search_and_filter(scope: scope, sort: 'cf_custom_label')
          expect(result.products.map(&:id)).to eq([product_2.id, product_3.id, product_1.id])
        end

        it 'sorts descending by -cf_* attribute' do
          result = provider.search_and_filter(scope: scope, sort: '-cf_custom_label')
          expect(result.products.map(&:id)).to eq([product_1.id, product_3.id, product_2.id])
        end

        it 'sorts with Ransack filters present (SELECT DISTINCT compatible)' do
          result = provider.search_and_filter(
            scope: scope,
            filters: { 'name_cont' => 'Blue' },
            sort: 'cf_custom_label'
          )
          expect(result.products.map(&:id)).to eq([product_3.id, product_1.id])
        end

        context 'with missing custom_field values' do
          before do
            product_2.custom_fields.destroy_all
          end

          it 'keeps missing values last when sorting ascending' do
            result = provider.search_and_filter(scope: scope, sort: 'cf_custom_label')
            expect(result.products.map(&:id)).to eq([product_3.id, product_1.id, product_2.id])
          end

          it 'keeps missing values last when sorting descending' do
            result = provider.search_and_filter(scope: scope, sort: '-cf_custom_label')
            expect(result.products.map(&:id)).to eq([product_1.id, product_3.id, product_2.id])
          end
        end
      end

      context 'with custom_field filters' do
        let!(:material) do
          create(:custom_field_definition, :short_text_field, :searchable,
                 namespace: 'custom', key: 'material')
        end
        let!(:weight) do
          create(:custom_field_definition, :number_field, :sortable,
                 namespace: 'custom', key: 'weight')
        end

        before do
          product_1.set_custom_field(material, 'wool-blend')
          product_2.set_custom_field(material, 'cotton')
          product_1.set_custom_field(weight, '10')
          product_2.set_custom_field(weight, '2')
          product_3.set_custom_field(weight, '3.5')
        end

        it 'filters text values with cont' do
          result = provider.search_and_filter(scope: scope, filters: { 'cf_custom_material_cont' => 'wool' })
          expect(result.products).to contain_exactly(product_1)
          expect(result.total_count).to eq(1)
        end

        it 'filters text values case-insensitively with i_cont' do
          result = provider.search_and_filter(scope: scope, filters: { 'cf_custom_material_i_cont' => 'WOOL' })
          expect(result.products).to contain_exactly(product_1)
        end

        it 'filters text values with eq' do
          result = provider.search_and_filter(scope: scope, filters: { 'cf_custom_material_eq' => 'cotton' })
          expect(result.products).to contain_exactly(product_2)
        end

        it 'filters text values with not_eq (value set and different)' do
          result = provider.search_and_filter(scope: scope, filters: { 'cf_custom_material_not_eq' => 'cotton' })
          expect(result.products).to contain_exactly(product_1)
        end

        it 'filters text values with start and end' do
          result = provider.search_and_filter(scope: scope, filters: { 'cf_custom_material_start' => 'wool' })
          expect(result.products).to contain_exactly(product_1)

          result = provider.search_and_filter(scope: scope, filters: { 'cf_custom_material_end' => 'blend' })
          expect(result.products).to contain_exactly(product_1)
        end

        it 'filters numerically rather than lexicographically' do
          result = provider.search_and_filter(scope: scope, filters: { 'cf_custom_weight_gteq' => '3' })
          expect(result.products).to contain_exactly(product_1, product_3)

          result = provider.search_and_filter(scope: scope, filters: { 'cf_custom_weight_lt' => '3' })
          expect(result.products).to contain_exactly(product_2)
        end

        it 'filters with present and blank' do
          result = provider.search_and_filter(scope: scope, filters: { 'cf_custom_material_present' => '1' })
          expect(result.products).to contain_exactly(product_1, product_2)

          result = provider.search_and_filter(scope: scope, filters: { 'cf_custom_material_blank' => '1' })
          expect(result.products).to contain_exactly(product_3)
        end

        it 'combines custom_field and ransack filters' do
          result = provider.search_and_filter(
            scope: scope,
            filters: { 'name_cont' => 'Blue', 'cf_custom_weight_gteq' => '5' }
          )
          expect(result.products).to contain_exactly(product_1)
        end

        it 'combines custom_field filters with custom_field sort' do
          result = provider.search_and_filter(
            scope: scope,
            filters: { 'cf_custom_weight_gteq' => '3' },
            sort: '-cf_custom_weight'
          )
          expect(result.products.map(&:id)).to eq([product_1.id, product_3.id])
        end

        it 'ignores non-numeric values on number predicates' do
          result = provider.search_and_filter(scope: scope, filters: { 'cf_custom_weight_gteq' => 'abc' })
          expect(result.total_count).to eq(3)
        end

        it 'ignores cf_ keys that match no definition' do
          result = provider.search_and_filter(scope: scope, filters: { 'cf_bogus_field_eq' => 'x' })
          expect(result.total_count).to eq(3)
        end
      end

      context "with 'manual' sort and a non-grouping filter" do
        subject(:result) { provider.search_and_filter(scope: scope, sort: 'manual', filters: { 'name_cont' => 'Blue' }) }

        it 'applies the filter and falls back to the default order' do
          expect(result.products).to include(product_1, product_3)
          expect(result.products).not_to include(product_2)
          expect(result.total_count).to eq(2)
        end
      end

      context 'with sortable number custom_fields' do
        let!(:definition) do
          create(:custom_field_definition, :number_field, :sortable,
                 namespace: 'custom', key: 'weight')
        end

        before do
          product_1.set_custom_field(definition, '10')
          product_2.set_custom_field(definition, '2')
          product_3.set_custom_field(definition, '3')
        end

        it 'sorts ascending numerically rather than lexicographically' do
          result = provider.search_and_filter(scope: scope, sort: 'cf_custom_weight')
          expect(result.products.map(&:id)).to eq([product_2.id, product_3.id, product_1.id])
        end

        it 'sorts descending numerically' do
          result = provider.search_and_filter(scope: scope, sort: '-cf_custom_weight')
          expect(result.products.map(&:id)).to eq([product_1.id, product_3.id, product_2.id])
        end
      end
    end

    describe '#filters' do
      let(:scope) { store.products }

      subject(:result) { provider.filters(scope: scope) }

      it 'returns a FiltersResult' do
        expect(result).to be_a(SearchProvider::FiltersResult)
      end

      it 'returns sort options as objects' do
        expect(result.sort_options).to be_an(Array)
        ids = result.sort_options.map { |o| o[:id] }
        expect(ids).to include('price', '-price', 'best_selling')
      end

      context 'with sortable custom_field definitions' do
        let!(:definition) do
          create(:custom_field_definition, :short_text_field, :sortable,
                 namespace: 'custom', key: 'label', label: 'Material')
        end

        it 'includes custom_field sort options' do
          ids = result.sort_options.map { |o| o[:id] }
          expect(ids).to include('cf_custom_label', '-cf_custom_label')
        end

        it 'includes human-readable labels for custom_field sort options' do
          by_id = result.sort_options.index_by { |o| o[:id] }
          expect(by_id['cf_custom_label'][:label]).to eq("Material (#{Spree.t(:sort_a_to_z)})")
          expect(by_id['-cf_custom_label'][:label]).to eq("Material (#{Spree.t(:sort_z_to_a)})")
        end
      end

      it 'returns total count' do
        expect(result.total_count).to eq(3)
      end

      context 'with text search' do
        subject(:result) { provider.filters(scope: scope, query: 'blue') }

        it 'returns filtered total count' do
          expect(result.total_count).to eq(2)
        end
      end
    end

    describe '#index' do
      it 'is a no-op' do
        expect { provider.index(product_1) }.not_to raise_error
      end
    end

    describe '#remove' do
      it 'is a no-op' do
        expect { provider.remove(product_1) }.not_to raise_error
      end
    end

    describe '#remove_by_id' do
      it 'is a no-op' do
        expect { provider.remove_by_id(product_1.id) }.not_to raise_error
      end
    end

    describe '#reindex' do
      it 'is a no-op' do
        expect { provider.reindex(store.products) }.not_to raise_error
      end
    end

  end
end
