require 'spec_helper'

RSpec.describe Spree::Admin::LineItemsController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:order) { create(:order_ready_to_ship, store: store) }
  let(:line_item) { order.line_items.first }

  describe '#new' do
    it 'returns a success response' do
      get :new, params: { order_id: order.to_param }
      expect(response).to render_template(:new)
    end
  end

  describe '#create' do
    let(:order) { create(:order, store: store) }
    let(:product) { create(:product_in_stock, stores: [store]) }

    it 'returns a success response' do
      post :create, params: { order_id: order.to_param, line_item: { variant_id: product.default_variant.id, quantity: 1 } }
      expect(response).to redirect_to(spree.edit_admin_order_path(order, line_item_updated: true))
      expect(order.line_items.count).to eq(1)
    end

    context 'when order is non-default currency' do
      let(:order) { create(:order, store: store, currency: 'EUR') }

      before do
        product.default_variant.prices.create(currency: 'EUR', amount: 89)
      end

      it 'returns a success response' do
        post :create, params: { order_id: order.to_param, line_item: { variant_id: product.default_variant.id, quantity: 1 } }

        line_items = order.line_items.last
        expect(line_items.price).to eq(89)
        expect(line_items.currency).to eq('EUR')
      end
    end
  end

  describe '#edit' do
    it 'returns a success response' do
      get :edit, params: { id: line_item.to_param, order_id: order.to_param }
      expect(response).to render_template(:edit)
    end
  end

  describe '#update' do
    it 'returns a success response' do
      put :update, params: { id: line_item.to_param, order_id: order.to_param, line_item: { quantity: 2 } }
      expect(response).to redirect_to(spree.edit_admin_order_path(order, line_item_updated: true))
    end
  end

  describe '#destroy' do
    it 'returns a success response' do
      delete :destroy, params: { id: line_item.to_param, order_id: order.to_param }
      expect(response).to redirect_to(spree.edit_admin_order_path(order, line_item_updated: true))
    end
  end
end
