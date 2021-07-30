require 'spec_helper'

describe Spree::OrdersController, type: :controller do
  let(:store) { Spree::Store.default }
  let(:user) { create(:user) }
  let(:product) { create(:product, stores: [store]) }
  let(:variant) { create(:variant, product: product) }

  context 'Order model mock' do
    let(:order) { create(:order, store: store) }

    before do
      allow(controller).to receive_messages(try_spree_current_user: user)
    end

    context '#update' do
      context 'with authorization' do
        before do
          allow(controller).to receive :check_authorization
          allow(controller).to receive_messages current_order: order
        end

        it 'renders the edit view (on failure)' do
          # email validation is only after address state
          order.update_column(:state, 'delivery')
          put :update, params: { order: { email: '' }, order_id: order.id }
          expect(response).to render_template :edit
        end

        it 'redirects to cart path (on success)' do
          allow(order).to receive(:update).and_return true
          put :update, params: { order_id: 1 }
          expect(response).to redirect_to(spree.cart_path)
        end
      end
    end

    context '#empty' do
      before do
        allow(controller).to receive :check_authorization
        allow(controller).to receive(:current_order).and_return(order)
        put :empty
      end

      it 'destroys line items in the current order' do
        expect(order.reload.line_items).to be_empty
      end

      it 'destroys adjustments' do
        expect(order.reload.adjustments).to be_empty
      end

      it 'redirects to spree cart path' do
        expect(response).to redirect_to(spree.cart_path)
      end
    end

    # Regression test for #2750
    context '#update' do
      before do
        allow(user).to receive :last_incomplete_spree_order
        allow(controller).to receive :set_current_order
      end

      it 'cannot update a blank order' do
        put :update, params: { order: { email: 'foo' } }
        expect(flash[:error]).to eq(Spree.t(:order_not_found))
        expect(response).to redirect_to(spree.root_path)
      end
    end
  end

  context 'line items quantity is 0' do
    let(:order) { create(:order, store: store) }
    let!(:line_item) { Spree::Cart::AddItem.call(order: order, variant: variant).value }

    before do
      allow(controller).to receive(:check_authorization)
      allow(controller).to receive_messages(current_order: order)
    end

    it 'removes line items on update' do
      expect(order.line_items.count).to eq 1
      put :update, params: { order: { line_items_attributes: { '0' => { id: line_item.id, quantity: 0 } } } }
      expect(order.reload.line_items.count).to eq 0
    end
  end

  describe '#show' do
    before do
      allow(controller).to receive(:check_authorization)
    end

    context 'order from current store' do
      let(:order) { create(:order, store: store) }

      let(:response) { get :show, params: { id: order.number } }

      it { expect(response).to render_template(:show) }
    end

    context 'order from different store' do
      let(:order) { create(:order, store: create(:store)) }

      it { expect { get :show, params: { id: order.number } }.to raise_error(ActiveRecord::RecordNotFound) }
    end
  end
end
