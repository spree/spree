require 'spec_helper'

module Spree
  describe Products::Find do
    let!(:product)              { create(:product, price: 15.99) }
    let!(:product_2)            { create(:product, discontinue_on: Time.current + 1.day, price: 23.99) }
    let!(:product_3)            { create(:variant).product }
    let!(:option_value)         { create(:option_value) }
    let!(:deleted_product)      { create(:product, deleted_at: Time.current - 1.day) }
    let!(:discontinued_product) { create(:product, discontinue_on: Time.current - 1.day) }

    before do
      product_3.variants.first.option_values << option_value
    end

    context 'include deleted' do
      it 'returns products with discontinued' do
        params = {
          filter: {
            ids: '',
            skus: '',
            price: '',
            currency: false,
            taxons: '',
            name: false,
            options: false,
            show_deleted: false,
            show_discontinued: true
          }
        }

        expect(
          Spree::Products::Find.new(
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
            name: false,
            options: false,
            show_deleted: true,
            show_discontinued: false
          }
        }

        expect(
          Spree::Products::Find.new(
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
            name: false,
            options: false,
            show_deleted: false,
            show_discontinued: false
          }
        }

        expect(
          Spree::Products::Find.new(
            scope: Spree::Product.all,
            params: params,
            current_currency: 'USD'
          ).execute
        ).to include(product, product_2)
      end
    end

    context 'filter by option values' do
      it 'returns products with proper option values' do
        params = {
          filter: {
            option_value_ids: [option_value.id]
          }
        }

        products = Spree::Products::Find.new(
          scope: Spree::Product.all,
          params: params,
          current_currency: 'USD'
        ).execute

        expect(products).to include(product_3)
        expect(products).to_not include(product)
        expect(products).to_not include(product_2)
      end
    end

    context 'ordered' do
      it 'returns products in default order' do
        params = {
          sort_by: 'default'
        }

        product_ids = Spree::Products::Find.new(
          scope: Spree::Product.all,
          params: params,
          current_currency: 'USD'
        ).execute.ids

        expect(product_ids).to match_array Spree::Product.available.ids
      end

      it 'returns products in newest-first order' do
        params = {
          sort_by: 'newest-first'
        }

        product_ids = Spree::Products::Find.new(
          scope: Spree::Product.all,
          params: params,
          current_currency: 'USD'
        ).execute.ids

        expect(product_ids).to match_array Spree::Product.available.order(available_on: :desc).ids
      end

      it 'returns products in price-high-to-low order' do
        params = {
          sort_by: 'price-high-to-low'
        }

        product_ids = Spree::Products::Find.new(
          scope: Spree::Product.all,
          params: params,
          current_currency: 'USD'
        ).execute.ids

        expect(product_ids).to match_array [product_2.id, product_3.id, product.id]
      end

      it 'returns products in price-low-to-high order' do
        params = {
          sort_by: 'price-low-to-high'
        }

        product_ids = Spree::Products::Find.new(
          scope: Spree::Product.all,
          params: params,
          current_currency: 'USD'
        ).execute.ids

        expect(product_ids).to match_array [product.id, product_3.id, product_2.id]
      end
    end
  end
end
