require 'spec_helper'

module Spree
  describe Products::Find do
    let(:store)                      { @default_store }
    let!(:product)                   { Timecop.travel(5.days.ago) { create(:product, name: 'Product 1', price: 15.99, stores: [store]) } }
    let!(:product_2)                 { Timecop.travel(4.days.ago) { create(:product, name: 'Product 2', discontinue_on: Time.current + 5.day, price: 23.99, stores: [store]) } }
    let!(:product_3)                 { Timecop.travel(3.days.ago) { create(:product, name: 'Product 3', price: 16.99, stores: [store]) } }
    let!(:option_value)              { create(:option_value) }
    let!(:deleted_product)           { Timecop.travel(2.days.ago) { create(:product, name: 'Deleted Product', deleted_at: Time.current - 1.day) } }
    let!(:discontinued_product)      { Timecop.travel(1.day.ago) { create(:product, name: 'Discontinued Product', status: 'archived') } }
    let!(:in_stock_product)          { Timecop.travel(1.hour.ago) { create(:product_in_stock, name: 'In Stock Product', price: 17.99) } }
    let!(:not_backorderable_product) { Timecop.travel(1.minute.ago) { create(:product_in_stock, :without_backorder, name: 'Not Backorderable Product', price: 18.99) } }

    context 'include discontinued' do
      it 'returns products with discontinued' do
        params = {
          filter: {
            ids: '',
            skus: '',
            price: '',
            currency: 'USD',
            taxons: '',
            concat_taxons: '',
            name: false,
            options: false,
            show_deleted: false,
            show_discontinued: true,
            in_stock: false
          }
        }

        expect(
          described_class.new(
            scope: Spree::Product.all,
            params: params
          ).execute
        ).to contain_exactly(product, product_2, product_3, discontinued_product, in_stock_product, not_backorderable_product)
      end
    end

    context 'include deleted' do
      it 'returns products with deleted' do
        params = {
          filter: {
            ids: '',
            skus: '',
            price: '',
            taxons: '',
            currency: 'USD',
            concat_taxons: '',
            name: false,
            options: false,
            show_deleted: true,
            show_discontinued: false,
            in_stock: false
          }
        }

        expect(
          described_class.new(
            scope: Spree::Product.all,
            params: params
          ).execute
        ).to contain_exactly(product, product_2, product_3, deleted_product, in_stock_product, not_backorderable_product)
      end
    end

    context 'in stock' do
      it 'returns products with variants in stock or backorderable' do
        params = {
          filter: {
            ids: '',
            skus: '',
            price: '',
            taxons: '',
            currency: 'USD',
            concat_taxons: '',
            name: false,
            options: false,
            show_deleted: false,
            show_discontinued: false,
            in_stock: true
          }
        }

        expect(
          described_class.new(
            scope: Spree::Product.all,
            params: params
          ).execute
        ).to contain_exactly(product, product_2, product_3, in_stock_product, not_backorderable_product)
      end
    end

    context 'backorderable' do
      it 'returns products with backorderable variants' do
        params = {
          filter: {
            ids: '',
            skus: '',
            price: '',
            taxons: '',
            currency: 'USD',
            concat_taxons: '',
            name: false,
            options: false,
            show_deleted: false,
            show_discontinued: false,
            in_stock: false,
            backorderable: true
          }
        }

        expect(
          described_class.new(
            scope: Spree::Product.all,
            params: params
          ).execute
        ).to contain_exactly(product, product_2, product_3, in_stock_product) # No not_backorderable_product.
      end
    end

    context 'purchasable' do
      it 'returns products with purchasable variants' do
        params = {
          filter: {
            ids: '',
            skus: '',
            price: '',
            taxons: '',
            currency: 'USD',
            concat_taxons: '',
            name: false,
            options: false,
            show_deleted: false,
            show_discontinued: false,
            in_stock: false,
            backorderable: false,
            purchasable: true
          }
        }

        expect(
          described_class.new(
            scope: Spree::Product.all,
            params: params
          ).execute
        ).to contain_exactly(product, product_2, product_3, in_stock_product, not_backorderable_product)
      end
    end

    context 'exclude discontinued and deleted' do
      it 'returns not discontinued and not deleted products' do
        params = {
          filter: {
            ids: '',
            skus: '',
            price: '',
            currency: 'USD',
            taxons: '',
            concat_taxons: '',
            name: false,
            options: false,
            show_deleted: false,
            show_discontinued: false,
            in_stock: false
          }
        }

        expect(
          described_class.new(
            scope: Spree::Product.all,
            params: params
          ).execute
        ).to contain_exactly(product, product_2, product_3, in_stock_product, not_backorderable_product)
      end
    end

    describe 'filter by options and option values' do
      subject(:products) do
        described_class.new(
          scope: Spree::Product.all,
          params: params
        ).execute
      end

      let(:option_type_1) { create :option_type, name: 'size' }
      let(:option_type_2) { create :option_type, name: 'state' }

      let(:option_value_1_1) { create :option_value, option_type: option_type_1, name: 's', presentation: 'S' }
      let(:option_value_1_2) { create :option_value, option_type: option_type_1, name: 'm', presentation: 'M' }
      let(:option_value_2_1) { create :option_value, option_type: option_type_2, name: 'old', presentation: 'Old' }
      let(:option_value_2_2) { create :option_value, option_type: option_type_2, name: 'new', presentation: 'New' }

      let(:product_1) { create :product, option_types: [option_type_1, option_type_2] }
      let(:product_2) { create :product, option_types: [option_type_1, option_type_2] }
      let(:product_3) { create :product, option_types: [option_type_1, option_type_2] }

      let!(:variant_1) { create :variant, product: product_1, option_values: [option_value_1_1, option_value_2_1] }
      let!(:variant_2) { create :variant, product: product_2, option_values: [option_value_1_2, option_value_2_2] }
      let!(:variant_3) { create :variant, product: product_3, option_values: [option_value_1_1, option_value_2_2] }

      context 'for options' do
        let(:params) do
          {
            filter: {
              options: ActionController::Parameters.new(
                size: 's',
                state: 'old'
              )
            }
          }
        end

        it 'returns products matching all given options' do
          expect(products).to contain_exactly(product_1)
        end
      end

      context 'for option values' do
        let(:option_value_ids) { [] }
        let(:params) do
          {
            filter: {
              option_value_ids: option_value_ids
            }
          }
        end

        context 'filtering by one option' do
          let(:option_value_ids) { [option_value_1_1.id] }

          it 'returns products with proper option values' do
            expect(products).to match_array([product_1, product_3])
          end
        end

        context 'filtering by several options' do
          let(:option_value_ids) { [option_value_1_1.id, option_value_2_2.id] }

          it 'returns products that have both options' do
            expect(products).to match_array([product_3])
          end
        end
      end
    end

    describe 'filter by taxons' do
      subject(:products) do
        described_class.new(
          scope: scope,
          params: params
        ).execute
      end

      let!(:scope) { Spree::Product.all }
      let(:parent_taxon) { child_taxon.parent }
      let(:child_taxon) { create(:taxon) }

      context 'one taxon is requested in params' do
        let(:params) { { store: store, filter: { taxons: parent_taxon.id } } }

        shared_examples 'returns distinct products associated both to self and descendants' do
          it { expect(products).to match_array [product, product_2] }
        end

        before do
          parent_taxon.products << product
          child_taxon.products << product_2
        end

        it_behaves_like 'returns distinct products associated both to self and descendants'

        context 'when product is already related to both taxons' do
          before { parent_taxon.products << product_2 }

          it_behaves_like 'returns distinct products associated both to self and descendants'
        end
      end

      context 'multiple taxons are requested' do
        let(:params) { { store: store, filter: { taxons: "#{taxon.id},#{taxon_2.id}" } } }
        let(:taxon) { create(:taxon) }
        let(:taxon_2) { create(:taxon) }

        before do
          taxon.products << product
          taxon_2.products << product_2
        end

        it { expect(products).to match_array [product, product_2] }
      end

      context 'multiple taxons + 1 concat_taxons are requested' do
        let(:params) { { store: store, filter: { taxons: "#{taxon.id},#{taxon_2.id}", concat_taxons: taxon_3.id.to_s } } }
        let(:taxon) { create(:taxon) }
        let(:taxon_2) { create(:taxon) }
        let(:taxon_3) { create(:taxon) }

        before do
          taxon.products << product
          taxon_2.products << product_2
          taxon_3.products << product_2
          taxon_3.products << product_3
        end

        it { expect(products).to match_array [product_2] }
      end

      context 'only multiple concat_taxons are requested' do
        let(:params) { { store: store, filter: { concat_taxons: "#{taxon_2.id},#{taxon_3.id}" } } }
        let(:taxon) { create(:taxon) }
        let(:taxon_2) { create(:taxon) }
        let(:taxon_3) { create(:taxon) }

        before do
          taxon.products << product
          taxon_2.products << product_2
          taxon_3.products << product_2
          taxon_3.products << product_3
        end

        it { expect(products).to match_array [product_2] }
      end

      context 'only one concat_taxons is requested' do
        let(:params) { { store: store, filter: { concat_taxons: taxon_3.id.to_s } } }
        let(:taxon) { create(:taxon) }
        let(:taxon_2) { create(:taxon) }
        let(:taxon_3) { create(:taxon) }

        before do
          taxon.products << product
          taxon_2.products << product_2
          taxon_3.products << product_2
          taxon_3.products << product_3
        end

        it { expect(products).to match_array [product_2, product_3] }
      end
    end

    describe 'filter by prices' do
      subject(:products) do
        described_class.new(
          scope: Spree::Product.all,
          params: params
        ).execute
      end

      let(:params) { { filter: { price: price_param } } }

      context 'for a price less than 20' do
        let(:price_param) { '0,20' }

        it { is_expected.to contain_exactly(product, product_3, in_stock_product, not_backorderable_product) }
      end

      context 'for a price between 16 and 24' do
        let(:price_param) { '16,24' }

        it { is_expected.to contain_exactly(product_2, product_3, in_stock_product, not_backorderable_product) }
      end

      context 'for a price more than 23' do
        let(:price_param) { '23,Infinity' }

        it do
          is_expected.to contain_exactly(product_2)
        end
      end
    end

    context 'ordered' do
      subject(:products) do
        described_class.new(
          scope: Spree::Product.all,
          params: params
        ).execute.to_a
      end

      context 'default' do
        context 'when not filtering by taxons' do
          let(:params) { { sort_by: 'default' } }

          it 'returns products in default order' do
            expect(products).to match_array Spree::Product.available.to_a
          end
        end

        context 'when filtering by taxons' do
          let(:params) do
            { store: store, sort_by: 'default', filter: { taxons: taxonomy.root.id } }
          end

          let(:taxonomy) { create(:taxonomy) }
          let(:child_taxon_1) { create(:taxon, taxonomy: taxonomy) }
          let(:child_taxon_2) { create(:taxon, taxonomy: taxonomy) }

          before do
            product.taxons << child_taxon_1
            product_2.taxons << child_taxon_1
            product_3.taxons << child_taxon_2

            # swap products positions
            product.classifications.find_by(taxon: child_taxon_1).update(position: 3)
            product_3.classifications.find_by(taxon: child_taxon_2).update(position: 2)
            product_2.classifications.find_by(taxon: child_taxon_1).update(position: 1)
          end

          it 'returns products ordered by associated taxon position' do
            expect(products).to eq [product_2, product_3, product]
          end
        end
      end

      context 'when sorting by newest-first' do
        let(:params) { { sort_by: 'newest-first' } }

        it 'returns products in newest-first order' do
          expect(products.to_a.map(&:name)).to eq([not_backorderable_product.name, in_stock_product.name, product_3.name, product_2.name, product.name])
        end
      end

      context 'when sorting by price-high-to-low' do
        let(:params) { { sort_by: 'price-high-to-low' } }

        it 'returns products in price-high-to-low order' do
          expect(products).to eq([product_2, not_backorderable_product, in_stock_product, product_3, product])
        end
      end

      context 'when sorting by price-low-to-high' do
        let(:params) { { sort_by: 'price-low-to-high' } }

        it 'returns products in price-low-to-high order' do
          expect(products).to eq([product, product_3, in_stock_product, not_backorderable_product, product_2])
        end
      end

      context 'when sorting by name-a-z' do
        let(:params) { { sort_by: 'name-a-z' } }

        it 'returns products in name-a-z order' do
          expect(products).to eq([in_stock_product, not_backorderable_product, product, product_2, product_3])
        end
      end

      context 'when sorting by name-z-a' do
        let(:params) { { sort_by: 'name-z-a' } }

        it 'returns products in name-z-a order' do
          expect(products).to eq([product_3, product_2, product, not_backorderable_product, in_stock_product])
        end
      end

      context 'when sorting by best-selling' do
        let(:params) { { sort_by: 'best-selling' } }

        before do
          product.store_products.find_by(store: store).update(units_sold_count: 10, revenue: 100)
          product_2.store_products.find_by(store: store).update(units_sold_count: 30, revenue: 200)
          product_3.store_products.find_by(store: store).update(units_sold_count: 30, revenue: 300)
          in_stock_product.store_products.find_by(store: store).update(units_sold_count: 1, revenue: 400)
        end

        it 'returns products in best-selling order' do
          expect(products).to eq([product_3, product_2, product, in_stock_product, not_backorderable_product])
        end
      end
    end

    describe 'filter by slug' do
      subject(:products) { described_class.new(scope: Spree::Product.all, params: params).execute }

      let(:params) { { filter: { slug: 'slug-1' } } }

      before { product.update(slug: 'slug-1') }

      context 'when product with given slug is present' do
        it 'returns products with the given slug' do
          expect(products).to contain_exactly(product)
        end
      end

      context 'when product with given slug is not present' do
        let(:params) { { filter: { slug: 'slug-2' } } }

        it 'returns all products' do
          expect(products).to be_empty
        end
      end

      context 'when slug is not present' do
        let(:params) { { filter: { slug: '' } } }

        it 'returns all products' do
          expect(products).to contain_exactly(product, product_2, product_3, in_stock_product, not_backorderable_product)
        end
      end
    end
  end
end
