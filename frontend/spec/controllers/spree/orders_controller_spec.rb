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

    context '#populate' do
      it 'creates a new order when none specified' do
        spree_post :populate, variant_id: variant.id
        expect(cookies.signed[:token]).not_to be_blank
        expect(Spree::Order.find_by(token: cookies.signed[:token])).to be_persisted
      end

      context 'with Variant' do
        it 'handles population' do
          expect do
            spree_post :populate, variant_id: variant.id, quantity: 5
          end.to change { user.orders.count }.by(1)
          order = user.orders.last
          expect(response).to redirect_to spree.cart_path(variant_id: variant.id)
          expect(order.line_items.size).to eq(1)
          line_item = order.line_items.first
          expect(line_item.variant_id).to eq(variant.id)
          expect(line_item.quantity).to eq(5)
        end

        it 'shows an error when population fails' do
          request.env['HTTP_REFERER'] = '/dummy_redirect'
          allow_any_instance_of(Spree::LineItem).to(
            receive(:valid?).and_return(false)
          )
          allow_any_instance_of(Spree::LineItem).to(
            receive_message_chain(:errors, :full_messages).
              and_return(['Order population failed'])
          )

          spree_post :populate, variant_id: variant.id, quantity: 5

          expect(response).to redirect_to('/dummy_redirect')
          expect(flash[:error]).to eq('Order population failed')
        end

        it 'shows an error when quantity is invalid' do
          request.env['HTTP_REFERER'] = '/dummy_redirect'

          spree_post(
            :populate,
            variant_id: variant.id, quantity: -1
          )

          expect(response).to redirect_to('/dummy_redirect')
          expect(flash[:error]).to eq(
            Spree.t(:please_enter_reasonable_quantity)
          )
        end
      end
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
          spree_put :update, { order: { email: '' } }, order_id: order.id
          expect(response).to render_template :edit
        end

        it 'redirects to cart path (on success)' do
          allow(order).to receive(:update_attributes).and_return true
          spree_put :update, {}, order_id: 1
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
        spree_put :empty
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
        spree_put :update, order: { email: 'foo' }
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
      spree_put :update, order: { line_items_attributes: { '0' => { id: line_item.id, quantity: 0 } } }
      expect(order.reload.line_items.count).to eq 0
    end
  end
end
