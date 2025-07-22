require 'spec_helper'

describe Spree::PoliciesController, type: :controller do
  let(:store) { @default_store }

  render_views

  before do
    allow(controller).to receive(:current_store).and_return(store)
  end

  describe 'GET #show' do
    context 'with valid policy types' do
      it 'renders privacy_policy' do
        get :show, params: { id: 'privacy_policy' }
        expect(assigns(:policy)).to eq(store.customer_privacy_policy)
        expect(response).to render_template(:show)
        expect(response).to have_http_status(:ok)
      end

      it 'renders terms_of_service' do
        get :show, params: { id: 'terms_of_service' }
        expect(assigns(:policy)).to eq(store.customer_terms_of_service)
        expect(response).to render_template(:show)
        expect(response).to have_http_status(:ok)
      end

      it 'renders returns_policy' do
        get :show, params: { id: 'returns_policy' }
        expect(assigns(:policy)).to eq(store.customer_returns_policy)
        expect(response).to render_template(:show)
        expect(response).to have_http_status(:ok)
      end

      it 'renders shipping_policy' do
        get :show, params: { id: 'shipping_policy' }
        expect(assigns(:policy)).to eq(store.customer_shipping_policy)
        expect(response).to render_template(:show)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid policy type' do
      it 'raises RecordNotFound error' do
        expect {
          get :show, params: { id: 'invalid_policy' }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
