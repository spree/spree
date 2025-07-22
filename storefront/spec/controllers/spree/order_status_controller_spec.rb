require 'spec_helper'

RSpec.describe Spree::OrderStatusController, type: :controller do
  let(:store) { @default_store }
  let(:order) { create(:completed_order_with_totals, store: store) }

  render_views

  before do
    allow(controller).to receive(:current_store).and_return(store)
  end

  describe 'GET #new' do
    before { get :new }

    it 'returns http success' do
      expect(response).to have_http_status(:success)
    end

    it 'renders the new template' do
      expect(response).to render_template(:new)
    end
  end

  describe 'POST #create' do
    before { order }

    context 'with valid order number and email' do
      before do
        post :create, params: { number: order.number, email: order.email }
      end

      it 'redirects to order path' do
        expect(response).to redirect_to(spree.order_path(order, token: order.token))
      end

      it 'returns redirect status' do
        expect(response).to have_http_status(:see_other)
      end
    end

    context 'with invalid order number' do
      before do
        post :create, params: { number: 'invalid', email: order.email }
      end

      it 'sets flash error message' do
        expect(flash[:error]).to eq Spree.t(:order_not_found)
      end

      it 'renders new template' do
        expect(response).to render_template(:new)
      end

      it 'returns unprocessable entity status' do
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with blank order number' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          post :create, params: { number: '', email: order.email }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
