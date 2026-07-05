require 'spec_helper'

RSpec.describe Spree::Admin::StockMovementsController, type: :controller do
  stub_authorization!
  render_views

  describe '#index' do
    let!(:stock_location_1) { create(:stock_location, name: 'Stock location 1') }
    let!(:stock_location_2) { create(:stock_location, name: 'Stock location 2') }

    let!(:variant_1) { create(:variant, create_stock: false, sku: 'shirt-1', product: create(:base_product, name: 'Shirt')) }
    let!(:stock_item_1) { create(:stock_item, variant: variant_1, stock_location: stock_location_1) }

    let!(:variant_2) { create(:variant, create_stock: false, sku: 'shoes-2', product: create(:base_product, name: 'Shoes')) }
    let!(:stock_item_2) { create(:stock_item, variant: variant_2, stock_location: stock_location_2) }

    let!(:movement_1) { create(:stock_movement, stock_item: stock_item_1, quantity: 10, action: 'received') }
    let!(:movement_2) { create(:stock_movement, stock_item: stock_item_2, quantity: -2, action: 'sold') }

    subject(:index) { get :index, params: params }

    let(:params) { {} }

    it 'lists all stock movements' do
      index
      expect(response).to be_ok

      expect(assigns[:collection]).to contain_exactly(movement_1, movement_2)
    end

    describe 'search' do
      let(:params) do
        {
          q: {
            stock_item_variant_product_name_cont: 'shoe'
          }
        }
      end

      it 'lists stock movements searched by the variant name' do
        index
        expect(response).to be_ok

        expect(assigns[:collection]).to contain_exactly(movement_2)
      end
    end

    describe 'filters' do
      let(:params) { { q: q } }

      context 'when filtering by stock location' do
        let(:q) { { stock_item_stock_location_id_eq: stock_location_1.id } }

        it 'lists stock movements filtered by the stock location' do
          index
          expect(response).to be_ok

          expect(assigns[:collection]).to contain_exactly(movement_1)
        end
      end
    end
  end
end
