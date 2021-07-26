require 'spec_helper'

module Spree
  module Admin
    describe StockItemsController, type: :controller do
      stub_authorization!

      let(:store) { Spree::Store.default }
      let(:store_2) { create(:store) }

      context 'formats' do
        let(:product) { create(:product, stores: [store]) }
        let(:product_2) { create(:product, stores: [store_2]) }

        let!(:stock_item) { create(:variant, product: product).stock_items.first }
        let!(:stock_item_2) { create(:variant, product: product_2).stock_items.first }

        it 'destroy stock item via js' do
          expect do
            delete :destroy, params: { format: :js, id: stock_item }
          end.to change(StockItem, :count).by(-1)
        end

        it 'cannot destroy stock from other store' do
          expect do
            delete :destroy, params: { format: :js, id: stock_item_2 }
          end.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end
end
