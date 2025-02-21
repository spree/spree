require 'spec_helper'

describe Spree::LineItemsController, type: :controller do
  let(:user) { create(:user) }
  let(:store) { Spree::Store.default }
  let(:order) { create(:order, store: store, user: user) }
  let(:product) { create(:product, stores: [store]) }
  let(:variant) { create(:variant, product: product) }
  let(:line_item) { create(:line_item, order: order, variant: variant) }

  render_views

  before do
    allow(controller).to receive_messages(try_spree_current_user: user)
    allow(controller).to receive_messages(current_order: order)
    allow(controller).to receive_messages(current_store: store)
  end

  context '#create' do
    it 'creates line item successfully' do
      expect do
        post :create, params: { variant_id: variant.id, quantity: 1 }, format: :turbo_stream
      end.to change(Spree::LineItem, :count).by(1)
    end

    it 'handles invalid variant id' do
      expect { post :create, params: { variant_id: 9999, quantity: 1 }, format: :turbo_stream }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context '#update' do
    before do
      allow(controller).to receive(:assign_order_with_lock)
      controller.instance_variable_set(:@order, order)
    end

    it 'updates line item quantity' do
      put :update, params: { id: line_item.id, line_item: { quantity: 3 } }, format: :turbo_stream
      expect(line_item.reload.quantity).to eq(3)
    end
  end

  context '#destroy' do
    before do
      allow(controller).to receive(:assign_order_with_lock)
      controller.instance_variable_set(:@order, order)
    end

    it 'deletes line item from order' do
      delete :destroy, params: { id: line_item.id }, format: :turbo_stream
      expect(order.line_items).not_to include(line_item)
    end
  end
end
