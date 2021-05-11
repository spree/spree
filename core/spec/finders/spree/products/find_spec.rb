require 'spec_helper'

module Spree
  describe Products::Find do
    let!(:product)              { create(:product, price: 15.99) }
    let!(:product_2)            { create(:product, discontinue_on: Time.current + 1.day, price: 23.99) }
    let!(:product_3)            { create(:variant, price: 19.99).product }
    let!(:option_value)         { create(:option_value) }
    let!(:deleted_product)      { create(:product, deleted_at: Time.current - 1.day) }
    let!(:discontinued_product) { create(:product, discontinue_on: Time.current - 1.day) }

    context 'include discontinued' do
      it 'returns products with discontinued' do
        params = {
          filter: {
            ids: '',
            skus: '',
            price: '',
            currency: false,
            taxons: '',
            concat_taxons: '',
            name: false,
            options: false,
            show_deleted: false,
            show_discontinued: true
          }
        }

        expect(
          described_class.new(
            scope: Spree::Product.all,
            params: params,
            current_currency: 'USD'
          ).execute
        ).to include(product, product_2, discontinued_product)
      end
    end

    context 'include deleted' do
      it 'returns products with deleted' do
        params = { filter: { show_deleted: true } }

        params = {
          filter: {
            ids: '',
            skus: '',
            price: '',
            currency: false,
            taxons: '',
            concat_taxons: '',
            name: false,
            options: false,
            show_deleted: true,
            show_discontinued: false
          }
        }

        expect(
          described_class.new(
            scope: Spree::Product.all,
            params: params,
            current_currency: 'USD'
          ).execute
        ).to include(product, product_2, deleted_product)
      end
    end

    context 'exclude discontinued and deleted' do
      it 'returns not discontinued and not deleted products' do
        params = {
          filter: {
            ids: '',
            skus: '',
            price: '',
            currency: false,
            taxons: '',
            concat_taxons: '',
            name: false,
            options: false,
            show_deleted: false,
            show_discontinued: false
          }
        }

        expect(
          described_class.new(
            scope: Spree::Product.all,
            params: params,
            current_currency: 'USD'
          ).execute
        ).to include(product, product_2)
      end
    end

    describe 'filter by option values' do
      subject(:products) do
        described_class.new(
          scope: Spree::Product.all,
          params: params,
          current_currency: 'USD'
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

    describe 'filter by taxons' do
      subject(:products) do
        described_class.new(
            scope: Spree::Product.all,
            params: params,
            current_currency: 'USD'
        ).execute
      end

      let(:parent_taxon) { child_taxon.parent }
      let(:child_taxon) { create(:taxon) }

      context 'one taxon is requested in params' do
        let(:params) { { filter: { taxons: parent_taxon.id } } }

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
        let(:params) { { filter: { taxons: "#{taxon.id},#{taxon_2.id}" } } }
        let(:taxon) { create(:taxon) }
        let(:taxon_2) { create(:taxon) }

        before do
          taxon.products << product
          taxon_2.products << product_2
        end

        it { expect(products).to match_array [product, product_2] }
      end

      context 'multiple taxons + 1 concat_taxons are requested' do
        let(:params) { { filter: { taxons: "#{taxon.id},#{taxon_2.id}", concat_taxons: "#{taxon_3.id}" } } }
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
        let(:params) { { filter: {concat_taxons: "#{taxon_2.id},#{taxon_3.id}" } } }
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
        let(:params) { { filter: {concat_taxons: "#{taxon_3.id}" } } }
        let(:taxon) { create(:taxon) }
        let(:taxon_2) { create(:taxon) }
        let(:taxon_3) { create(:taxon) }

        before do
          taxon.products << product
          taxon_2.products << product_2
          taxon_3.products << product_2
          taxon_3.products << product_3
        end

        it { expect(products).to match_array [product_2,product_3] }
      end
    end

    describe 'filter by prices' do
      subject(:products) do
        described_class.new(
          scope: Spree::Product.all,
          params: params,
          current_currency: 'USD'
        ).execute
      end

      let(:params) { { filter: { price: price_param } } }

      context 'for a price less than 20' do
        let(:price_param) { '0,20' }

        it { is_expected.to contain_exactly(product, product_3) }
      end

      context 'for a price between 16 and 24' do
        let(:price_param) { '16,24' }

        it { is_expected.to contain_exactly(product_2, product_3) }
      end

      context 'for a price more than 23' do
        let(:price_param) { '23,Infinity' }

        it do
          is_expected.to contain_exactly(product_2)
        end
      end
    end

    context 'ordered' do
      context 'default' do
        subject(:products) do
          described_class.new(
            scope: Spree::Product.all,
            params: params,
            current_currency: 'USD'
          ).execute
        end

        context 'when not filtering by taxons' do
          let(:params) { { sort_by: 'default' } }

          it 'returns products in default order' do
            expect(products.ids).to match_array Spree::Product.available.ids
          end
        end

        context 'when filtering by taxons' do
          let(:taxonomy) { create(:taxonomy) }
          let(:child_taxon) { create(:taxon, taxonomy: taxonomy) }

          before do
            product.taxons << child_taxon
            product_2.taxons << child_taxon

            # swap products positions
            product.classifications.find_by(taxon: child_taxon).update(position: 2)
            product_2.classifications.find_by(taxon: child_taxon).update(position: 1)
          end

          let(:params) { { sort_by: 'default', filter: { taxons: taxonomy.root.id } } }

          it 'returns products ordered by associated taxon position' do
            expect(products).to match_array [product_2, product]
          end
        end
      end

      it 'returns products in newest-first order' do
        params = {
          sort_by: 'newest-first'
        }

        product_ids = described_class.new(
          scope: Spree::Product.all,
          params: params,
          current_currency: 'USD'
        ).execute.map(&:id)

        expect(product_ids).to match_array Spree::Product.available.order(available_on: :desc).map(&:id)
      end

      it 'returns products in price-high-to-low order' do
        params = {
          sort_by: 'price-high-to-low'
        }

        products = described_class.new(
          scope: Spree::Product.all,
          params: params,
          current_currency: 'USD'
        ).execute.to_a

        expect(products).to match_array [product_2, product_3, product]
      end

      it 'returns products in price-low-to-high order' do
        params = {
          sort_by: 'price-low-to-high'
        }

        products = described_class.new(
          scope: Spree::Product.all,
          params: params,
          current_currency: 'USD'
        ).execute

        expect(products).to match_array [product, product_3, product_2]
      end
    end
  end
end
