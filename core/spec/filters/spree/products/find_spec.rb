require 'spec_helper'

module Spree
  describe Products::Find do
    let!(:product)              { create(:product) }
    let!(:product_2)            { create(:product, discontinue_on: Time.current + 1.day) }
    let!(:deleted_product)      { create(:product, deleted_at: Time.current - 1.day) }
    let!(:discontinued_product) { create(:product, discontinue_on: Time.current - 1.day) }

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
  end
end
