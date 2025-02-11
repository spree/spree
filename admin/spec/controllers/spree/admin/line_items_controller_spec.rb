require 'spec_helper'

RSpec.describe Spree::Admin::LineItemsController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { Spree::Store.default }
  let(:order) { create(:order_ready_to_ship, store: store) }
  let(:line_item) { order.line_items.first }

  describe '#new' do
    it 'returns a success response' do
      get :new, params: { order_id: order.number }
      expect(response).to render_template(:new)
    end
  end

  describe '#create' do
    let(:order) { create(:order, store: store) }
    let(:product) { create(:product_in_stock, stores: [store]) }

    it 'returns a success response' do
      post :create, params: { order_id: order.number, line_item: { variant_id: product.default_variant.id, quantity: 1 } }
      expect(response).to redirect_to(spree.edit_admin_order_path(order, line_item_updated: true))
      expect(order.line_items.count).to eq(1)
    end
  end

  describe '#edit' do
    it 'returns a success response' do
      get :edit, params: { id: line_item.id, order_id: order.number }
      expect(response).to render_template(:edit)
    end
  end

  describe '#update' do
    it 'returns a success response' do
      put :update, params: { id: line_item.id, order_id: order.number, line_item: { quantity: 2 } }
      expect(response).to redirect_to(spree.edit_admin_order_path(order, line_item_updated: true))
    end
  end

  describe '#destroy' do
    it 'returns a success response' do
      delete :destroy, params: { id: line_item.id, order_id: order.number }
      expect(response).to redirect_to(spree.edit_admin_order_path(order, line_item_updated: true))
    end
  end
end
