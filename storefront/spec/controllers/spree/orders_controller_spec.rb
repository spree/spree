require 'spec_helper'

describe Spree::OrdersController, type: :controller do
  let(:store) { @default_store }
  let(:user) { create(:user) }
  let(:product) { create(:product, stores: [store]) }
  let(:variant) { create(:variant, product: product) }

  render_views

  before do
    allow(controller).to receive_messages(try_spree_current_user: user)
    allow(controller).to receive(:current_store).and_return(store)
  end

  describe '#edit' do
    let(:order) { create(:order_with_totals, store: store, user: user) }

    before do
      allow(controller).to receive_messages try_spree_current_user: user
      allow(controller).to receive_messages spree_current_user: user
      allow(controller).to receive_messages current_order: order
    end

    it 'render edit template' do
      get :edit
      expect(response).to render_template(:edit)
      expect(flash[:error]).to eq(nil)
    end

    it 'removes line item and render discontinued flash message' do
      product = order.products.first
      product.update_columns(status: 'archive')
      get :edit
      expect(flash[:error]).to match(Spree.t('cart_line_item.discontinued', li_name: product.name))
    end

    it 'removes line item and render out of stock flash message' do
      product = order.products.first
      product.stock_items.update_all(count_on_hand: 0, backorderable: false)
      get :edit

      expect(flash[:error]).to match(Spree.t('cart_line_item.out_of_stock', li_name: product.name))
    end
  end

  context 'Order model mock' do
    let(:order) { create(:order, store: store) }

    before do
      allow(controller).to receive_messages(try_spree_current_user: user)
    end

    describe '#update' do
      context 'with authorization' do
        before do
          allow(controller).to receive :check_authorization
          allow(controller).to receive_messages current_order: order
        end

        it 'renders the edit view (on failure)' do
          # email validation is only after address state
          order.update_column(:state, 'payment')
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

    # Regression test for #2750
    describe '#update' do
      before do
        allow(user).to receive :last_incomplete_spree_order
        allow(controller).to receive :set_current_order
      end

      it 'cannot update a blank order' do
        put :update, params: { order: { email: 'foo' } }
        expect(response.status).to eq(302)
        expect(response).to redirect_to(spree.cart_path)
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
    let(:order) { create(:completed_order_with_totals, store: store) }
    let(:user) { nil }

    it 'renders the show template' do
      get :show, params: { id: order.number, token: order.token }
      expect(response).to render_template(:show)
    end

    context 'when order is not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect do
          get :show, params: { id: 'invalid', token: order.token }
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when order does not require ship address' do
      let(:digital_shipping_method) { create(:digital_shipping_method) }
      let(:digital_product) { create(:product, shipping_category: digital_shipping_method.shipping_categories.first) }
      let(:order) { create(:completed_order_with_totals, store: store, user: user, ship_address: nil, variants: [digital_product.default_variant]) }

      it 'renders the show template' do
        expect(order.digital?).to be_truthy
        expect(order.requires_ship_address?).to be_falsey
        get :show, params: { id: order.number, token: order.token }
        expect(response).to render_template(:show)
        expect(response.body).not_to include(Spree.t(:delivery_address))
      end
    end

    context 'when order was free and doesn\'t require billing address' do
      let(:order) { create(:completed_order_with_totals, store: store, user: user, bill_address: nil) }

      it 'renders the show template' do
        get :show, params: { id: order.number, token: order.token }
        expect(response).to render_template(:show)
        expect(response.body).not_to include(Spree.t(:billing_address))
      end
    end

    context 'when token is invalid' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect { get :show, params: { id: order.number, token: 'invalid' } }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when token is missing' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect { get :show, params: { id: order.number, token: '' } }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
