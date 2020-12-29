require 'spec_helper'

describe Spree::OrdersController, type: :controller do
  let(:user) { create(:user) }

  context 'Order model mock' do
    let(:order) do
      Spree::Order.create!
    end
    let(:variant) { create(:variant) }

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
      end

      it 'destroys line items in the current order' do
        allow(controller).to receive(:current_order).and_return(order)
        expect(order).to receive(:empty!)
        put :empty
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
    let(:order) { Spree::Order.create }
    let(:variant) { create(:variant) }
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
end
