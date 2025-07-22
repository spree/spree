require 'spec_helper'

describe Spree::Account::OrdersController, type: :controller do
  let(:store) { @default_store }
  let(:user) { create(:user) }
  let(:order) { create(:completed_order_with_totals, user: user, store: store) }

  render_views

  before do
    allow(controller).to receive(:current_store).and_return(store)
    allow(controller).to receive(:spree_login_path).and_return('/login')
  end

  describe '#index' do
    subject { get :index }

    context 'when user is logged in' do
      before do
        allow(controller).to receive_messages try_spree_current_user: user
        allow(controller).to receive_messages spree_current_user: user
      end

      it 'lists orders for the user' do
        order # create the order
        subject
        expect(assigns(:orders)).to include(order)
        expect(response).to have_http_status(:ok)
      end

      it 'paginates orders' do
        subject
        expect(assigns(:orders)).to respond_to(:total_pages)
      end

      it 'renders the index template' do
        subject
        expect(response).to render_template(:index)
      end
    end

    context 'when user is not logged in' do
      it 'redirects to login page' do
        expect(subject).to have_http_status(302)
      end
    end
  end

  describe '#show' do
    subject { get :show, params: { id: order.number } }

    context 'when user is logged in' do
      before do
        allow(controller).to receive_messages try_spree_current_user: user
        allow(controller).to receive_messages spree_current_user: user
      end

      it 'shows the order details' do
        subject
        expect(assigns(:order)).to eq order
        expect(response).to have_http_status(:ok)
      end

      it 'renders the order details' do
        subject
        expect(response).to render_template(:show)
      end

      context 'when order number does not exist' do
        subject { get :show, params: { id: 'invalid' } }

        it 'raises ActiveRecord::RecordNotFound' do
          expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context 'when user is not logged in' do
      it 'redirects to login page' do
        expect(subject).to have_http_status(302)
      end
    end
  end
end
