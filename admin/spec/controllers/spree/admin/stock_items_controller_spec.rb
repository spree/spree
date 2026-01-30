require 'spec_helper'

RSpec.describe Spree::Admin::StockItemsController, type: :controller do
  stub_authorization!
  render_views

  describe '#index' do
    let!(:stock_location_1) { create(:stock_location, name: 'Stock location 1') }
    let!(:stock_location_2) { create(:stock_location, name: 'Stock location 2') }

    let!(:variant_1) { create(:variant, create_stock: false, sku: 'shirt-1', product: create(:base_product, name: 'Shirt')) }
    let!(:variant_1_stock_1) { create(:stock_item, variant: variant_1, stock_location: stock_location_1) }
    let!(:variant_1_stock_2) { create(:stock_item, variant: variant_1, stock_location: stock_location_2) }

    let!(:variant_2) { create(:variant, create_stock: false, sku: 'shoes-2', product: create(:base_product, name: 'Shoes')) }
    let!(:variant_2_stock_1) { create(:stock_item, variant: variant_2, stock_location: stock_location_1) }
    let!(:variant_2_stock_2) { create(:stock_item, variant: variant_2, stock_location: stock_location_2) }

    subject(:index) { get :index, params: params }

    let(:params) { {} }

    it 'lists all stock items' do
      index
      expect(response).to be_ok

      expect(assigns[:collection]).to contain_exactly(
        variant_1_stock_1, variant_1_stock_2,
        variant_2_stock_1, variant_2_stock_2
      )
    end

    describe 'search' do
      let(:params) do
        {
          q: {
            variant_product_name_cont: 'shoe'
          }
        }
      end

      it 'lists stock items searched by the variant name' do
        index
        expect(response).to be_ok

        expect(assigns[:collection]).to contain_exactly(variant_2_stock_1, variant_2_stock_2)
      end
    end

    describe 'filters' do
      let(:params) { { q: q } }

      context 'when filtering by SKU' do
        let(:q) { { variant_sku_cont: 'shirt' } }

        it 'lists stock items filtered by SKU' do
          index
          expect(response).to be_ok

          expect(assigns[:collection]).to contain_exactly(variant_1_stock_1, variant_1_stock_2)
        end
      end

      context 'when filtering by the location' do
        let(:q) { { stock_location_id_eq: stock_location_2.id } }

        it 'lists stock items filtered by the stock location' do
          index
          expect(response).to be_ok

          expect(assigns[:collection]).to contain_exactly(variant_1_stock_2, variant_2_stock_2)
        end
      end
    end
  end

  describe '#update' do
    let!(:stock_item) { create(:stock_item, count_on_hand: 100) }

    subject(:update) { patch :update, params: params, format: :turbo_stream }

    let(:params) { { id: stock_item.to_param, stock_item: { backorderable: true, count_on_hand: 99 } } }

    it 'updates the stock item' do
      update
      expect(stock_item.reload.backorderable).to be(true)
      expect(stock_item.reload.count_on_hand).to eq(99)
    end
  end
end
