require 'spec_helper'

describe Spree::LineItemsController, type: :controller do
  let(:user) { create(:user) }
  let(:store) { @default_store }
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

    context 'when adding item fails' do
      let(:add_item_service) { instance_double(Spree::Cart::AddItem, call: result) }
      let(:result) { double('result', failure?: true, success?: false, value: double('error_object', errors: double('errors', full_messages: ['Item could not be added to cart']))) }

      before do
        allow(Spree::Cart::AddItem).to receive(:new).and_return(add_item_service)
      end

      it 'responds with an error' do
        post :create, params: { variant_id: variant.id, quantity: 1 }, format: :turbo_stream

        expect(response).to have_http_status(:ok)

        expect(assigns(:error)).to eq('Item could not be added to cart')
        expect(flash.now[:error]).to eq('Item could not be added to cart')
      end
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

    context 'when setting quantity fails' do
      let(:set_quantity_service) { instance_double(Spree::Cart::SetQuantity, call: result) }
      let(:result) { double('result', failure?: true, success?: false, value: double('error_object', errors: double('errors', full_messages: ['Quantity must be greater than 0']))) }

      before do
        allow(Spree::Cart::SetQuantity).to receive(:new).and_return(set_quantity_service)
      end

      it 'responds with an error' do
        put :update, params: { id: line_item.id, line_item: { quantity: 0 } }, format: :turbo_stream

        expect(response).to have_http_status(:ok)

        expect(assigns(:error)).to eq('Quantity must be greater than 0')
        expect(flash.now[:error]).to eq('Quantity must be greater than 0')
      end
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

    context 'when removing item fails' do
      let(:remove_item_service) { instance_double(Spree::Cart::RemoveLineItem, call: result) }
      let(:result) { double('result', failure?: true, success?: false, value: double('error_object', errors: double('errors', full_messages: ['Item could not be removed from cart']))) }

      before do
        allow(Spree::Cart::RemoveLineItem).to receive(:new).and_return(remove_item_service)
      end

      it 'responds with an error' do
        delete :destroy, params: { id: line_item.id }, format: :turbo_stream

        expect(response).to have_http_status(:ok)
        expect(assigns(:error)).to eq('Item could not be removed from cart')
        expect(flash.now[:error]).to eq('Item could not be removed from cart')
        expect(remove_item_service).to have_received(:call).with(order: order, line_item: line_item)
      end
    end
  end
end
